#!/usr/bin/env bash

#==============================================================================
# JENKINS REQUIRED CHECK RECONCILIATION
#==============================================================================

set -euo pipefail

action="${1:-plan}"
confirmation="${2:-}"
owner="${GITHUB_OWNER:-bharathadigopula}"
jenkins_context="${JENKINS_CONTEXT:-continuous-integration/jenkins}"
jenkins_max_age_seconds="${JENKINS_MAX_AGE_SECONDS:-604800}"
apply_confirmation="MIGRATE_REQUIRED_CHECKS_TO_JENKINS"
rollback_confirmation="ROLLBACK_REQUIRED_CHECKS_FROM_JENKINS"
repositories=(
  github-pipeline-templates
  jenkins-controller-automation
  jenkins-pipeline-templates
  monitoring-stack-automation
  shared-host-automation
  terraform-oci-modules
)

case "$action" in
  plan)
    ;;
  apply)
    if [[ "$confirmation" != "$apply_confirmation" ]]; then
      printf 'Apply requires confirmation: %s\n' "$apply_confirmation" >&2
      exit 1
    fi
    ;;
  rollback)
    if [[ "$confirmation" != "$rollback_confirmation" ]]; then
      printf 'Rollback requires confirmation: %s\n' "$rollback_confirmation" >&2
      exit 1
    fi
    ;;
  *)
    printf 'Usage: %s [plan|apply|rollback] [confirmation]\n' "$0" >&2
    exit 1
    ;;
esac

for command_name in gh jq; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Required command is unavailable: %s\n' "$command_name" >&2
    exit 1
  fi
done

expected_actions_contexts() {
  case "$1" in
    github-pipeline-templates)
      printf '%s\n' '["Validate OCI bootstrap workflow / Terraform OCI bootstrap","Validate reusable workflow / Terraform validation"]'
      ;;
    jenkins-controller-automation | jenkins-pipeline-templates | monitoring-stack-automation | shared-host-automation)
      printf '%s\n' '["validate"]'
      ;;
    terraform-oci-modules)
      printf '%s\n' '["Validate compute-instance / Terraform validation","Validate identity-compartment / Terraform validation","Validate object-storage-bucket / Terraform validation","Validate vcn / Terraform validation"]'
      ;;
    *)
      printf 'Unsupported repository: %s\n' "$1" >&2
      return 1
      ;;
  esac
}

normalize_contexts() {
  jq -c 'sort'
}

jenkins_contexts() {
  jq -nc --arg context "$jenkins_context" '[$context]'
}

status_check_route() {
  printf 'repos/%s/%s/branches/main/protection/required_status_checks\n' "$owner" "$1"
}

protection_route() {
  printf 'repos/%s/%s/branches/main/protection\n' "$owner" "$1"
}

branch_route() {
  printf 'repos/%s/%s/branches/main\n' "$owner" "$1"
}

read_branch() {
  gh api \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "$(branch_route "$1")"
}

read_protection() {
  gh api \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "$(status_check_route "$1")"
}

read_recent_jenkins_status() {
  gh api \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "repos/$owner/$1/commits/main/statuses?per_page=100" |
    jq -ec \
      --arg context "$jenkins_context" \
      --argjson max_age "$jenkins_max_age_seconds" \
      '[.[] | select(.context == $context)] | first |
       select(.state == "success") |
       select((now - (.updated_at | fromdateiso8601)) <= $max_age)'
}

desired_contexts_for_action() {
  if [[ "$action" == "rollback" ]]; then
    expected_actions_contexts "$1"
  else
    jenkins_contexts
  fi
}

validate_current_contexts() {
  local repository="$1"
  local current_contexts="$2"
  local actions_contexts
  local desired_jenkins_contexts

  actions_contexts=$(expected_actions_contexts "$repository" | normalize_contexts)
  desired_jenkins_contexts=$(jenkins_contexts | normalize_contexts)

  if [[ "$current_contexts" != "$actions_contexts" && "$current_contexts" != "$desired_jenkins_contexts" ]]; then
    printf 'Required-check drift detected for %s: %s\n' "$repository" "$current_contexts" >&2
    return 1
  fi
}

declare -a strict_values=()
declare -a current_context_values=()
declare -a protected_values=()

for repository in "${repositories[@]}"; do
  branch=$(read_branch "$repository")
  protected=$(jq -er '.protected | if type == "boolean" then tostring else error("protected must be boolean") end' <<<"$branch")
  desired_contexts=$(desired_contexts_for_action "$repository" | normalize_contexts)

  if [[ "$protected" == "true" ]]; then
    protection=$(read_protection "$repository")
    strict=$(jq -er '.strict | if type == "boolean" then tostring else error("strict must be boolean") end' <<<"$protection")
    current_contexts=$(jq -c '.contexts | sort' <<<"$protection")
    validate_current_contexts "$repository" "$current_contexts"
  elif [[ "$repository" == "shared-host-automation" && "$action" != "rollback" ]]; then
    strict=true
    current_contexts='[]'
  else
    printf 'Branch protection is unavailable for %s\n' "$repository" >&2
    exit 1
  fi

  protected_values+=("$protected")
  strict_values+=("$strict")
  current_context_values+=("$current_contexts")

  printf 'repository=%s protected=%s strict=%s current=%s desired=%s\n' \
    "$repository" "$protected" "$strict" "$current_contexts" "$desired_contexts"

  if [[ "$action" == "apply" ]]; then
    if ! read_recent_jenkins_status "$repository" >/dev/null; then
      printf 'Recent successful Jenkins status is missing for %s\n' "$repository" >&2
      exit 1
    fi
    printf 'jenkins_status=%s state=success age_limit_seconds=%s\n' \
      "$repository" "$jenkins_max_age_seconds"
  fi
done

if [[ "$action" == "plan" ]]; then
  printf 'required_checks_plan=ready\n'
  exit 0
fi

for index in "${!repositories[@]}"; do
  repository="${repositories[$index]}"
  protected="${protected_values[$index]}"
  strict="${strict_values[$index]}"
  current_contexts="${current_context_values[$index]}"
  desired_contexts=$(desired_contexts_for_action "$repository" | normalize_contexts)

  if [[ "$protected" == "false" ]]; then
    payload=$(jq -nc --argjson contexts "$desired_contexts" '{
      required_status_checks: {strict: true, contexts: $contexts},
      enforce_admins: true,
      required_pull_request_reviews: {
        dismiss_stale_reviews: true,
        require_code_owner_reviews: false,
        required_approving_review_count: 0,
        require_last_push_approval: false
      },
      restrictions: null,
      required_linear_history: true,
      allow_force_pushes: false,
      allow_deletions: false,
      block_creations: false,
      required_conversation_resolution: true,
      lock_branch: false,
      allow_fork_syncing: false
    }')
    updated_protection=$(
      printf '%s' "$payload" |
        gh api \
          --method PUT \
          -H 'Accept: application/vnd.github+json' \
          -H 'X-GitHub-Api-Version: 2022-11-28' \
          "$(protection_route "$repository")" \
          --input -
    )
    updated_strict=$(jq -er '.required_status_checks.strict | if type == "boolean" then tostring else error("strict must be boolean") end' <<<"$updated_protection")
    updated_contexts=$(jq -c '.required_status_checks.contexts | sort' <<<"$updated_protection")

    if [[ "$updated_strict" != "true" || "$updated_contexts" != "$desired_contexts" ]]; then
      printf 'GitHub returned unexpected protection for %s\n' "$repository" >&2
      exit 1
    fi

    jq -e '
      .enforce_admins.enabled == true and
      .required_pull_request_reviews.dismiss_stale_reviews == true and
      .required_pull_request_reviews.require_code_owner_reviews == false and
      .required_pull_request_reviews.required_approving_review_count == 0 and
      .required_pull_request_reviews.require_last_push_approval == false and
      .required_linear_history.enabled == true and
      .allow_force_pushes.enabled == false and
      .allow_deletions.enabled == false and
      .block_creations.enabled == false and
      .required_conversation_resolution.enabled == true and
      .lock_branch.enabled == false and
      .allow_fork_syncing.enabled == false
    ' <<<"$updated_protection" >/dev/null

    printf 'required_checks=%s state=created\n' "$repository"
    continue
  fi

  if [[ "$current_contexts" == "$desired_contexts" ]]; then
    printf 'required_checks=%s state=unchanged\n' "$repository"
    continue
  fi

  payload=$(jq -nc --argjson contexts "$desired_contexts" '{contexts: $contexts}')
  updated_protection=$(
    printf '%s' "$payload" |
      gh api \
        --method PATCH \
        -H 'Accept: application/vnd.github+json' \
        -H 'X-GitHub-Api-Version: 2022-11-28' \
        "$(status_check_route "$repository")" \
        --input -
  )
  updated_strict=$(jq -er '.strict | if type == "boolean" then tostring else error("strict must be boolean") end' <<<"$updated_protection")
  updated_contexts=$(jq -c '.contexts | sort' <<<"$updated_protection")

  if [[ "$updated_strict" != "$strict" ]]; then
    printf 'GitHub changed strict mode for %s\n' "$repository" >&2
    exit 1
  fi

  if [[ "$updated_contexts" != "$desired_contexts" ]]; then
    printf 'GitHub returned unexpected contexts for %s: %s\n' "$repository" "$updated_contexts" >&2
    exit 1
  fi

  printf 'required_checks=%s state=updated\n' "$repository"
done

printf 'required_checks_%s=ready\n' "$action"