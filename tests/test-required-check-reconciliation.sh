#!/usr/bin/env bash

#==============================================================================
# REQUIRED CHECK RECONCILIATION TEST
#==============================================================================

set -euo pipefail

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
temporary_directory=$(mktemp -d)
mock_bin="$temporary_directory/bin"
patch_log="$temporary_directory/patches"
mkdir -p "$mock_bin"
trap 'rm -rf "$temporary_directory"' EXIT

cat > "$mock_bin/gh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

method=GET
route=
payload=

while (($# > 0)); do
  case "$1" in
    --method)
      method="$2"
      shift 2
      ;;
    -H)
      shift 2
      ;;
    --input)
      payload=$(cat)
      shift 2
      ;;
    *)
      route="$1"
      shift
      ;;
  esac
done

IFS=/ read -r _ _ repository resource _ <<<"$route"

if [[ "$resource" == "commits" ]]; then
  updated_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  jq -nc --arg updated_at "$updated_at" '[{
    context: "continuous-integration/jenkins",
    state: "success",
    updated_at: $updated_at
  }]'
  exit 0
fi

if [[ "$resource" == "branches" && "$route" != */protection* ]]; then
  protected=true
  if [[ "$repository" == "shared-host-automation" && "${MOCK_SHARED_PROTECTED:-false}" != "true" ]]; then
    protected=false
  fi
  jq -nc --argjson protected "$protected" '{protected: $protected}'
  exit 0
fi

case "$repository" in
  github-pipeline-templates)
    actions='["Validate OCI bootstrap workflow / Terraform OCI bootstrap","Validate reusable workflow / Terraform validation"]'
    ;;
  jenkins-controller-automation | jenkins-pipeline-templates | monitoring-stack-automation | shared-host-automation)
    actions='["validate"]'
    ;;
  terraform-oci-modules)
    actions='["Validate compute-instance / Terraform validation","Validate identity-compartment / Terraform validation","Validate object-storage-bucket / Terraform validation","Validate vcn / Terraform validation"]'
    ;;
esac

strict=true
if [[ "$repository" == "monitoring-stack-automation" ]]; then
  strict=false
fi

case "${MOCK_CURRENT:-actions}" in
  actions)
    contexts="$actions"
    ;;
  jenkins)
    contexts='["continuous-integration/jenkins"]'
    ;;
  drift)
    contexts='["unexpected/check"]'
    ;;
esac

if [[ "$method" == "PATCH" ]]; then
  contexts=$(jq -c '.contexts' <<<"$payload")
  printf 'PATCH %s %s\n' "$repository" "$contexts" >> "$MOCK_PATCH_LOG"
fi

if [[ "$method" == "PUT" ]]; then
  contexts=$(jq -c '.required_status_checks.contexts' <<<"$payload")
  printf 'PUT %s %s\n' "$repository" "$contexts" >> "$MOCK_PATCH_LOG"
  jq -nc --argjson payload "$payload" '{
    required_status_checks: {
      strict: $payload.required_status_checks.strict,
      contexts: $payload.required_status_checks.contexts
    },
    enforce_admins: {enabled: $payload.enforce_admins},
    required_pull_request_reviews: $payload.required_pull_request_reviews,
    required_linear_history: {enabled: $payload.required_linear_history},
    allow_force_pushes: {enabled: $payload.allow_force_pushes},
    allow_deletions: {enabled: $payload.allow_deletions},
    block_creations: {enabled: $payload.block_creations},
    required_conversation_resolution: {enabled: $payload.required_conversation_resolution},
    lock_branch: {enabled: $payload.lock_branch},
    allow_fork_syncing: {enabled: $payload.allow_fork_syncing}
  }'
  exit 0
fi

jq -nc --argjson strict "$strict" --argjson contexts "$contexts" '{strict: $strict, contexts: $contexts}'
MOCK
chmod +x "$mock_bin/gh"

export PATH="$mock_bin:$PATH"
export MOCK_PATCH_LOG="$patch_log"

plan_output=$(bash "$repository_root/scripts/github/reconcile-required-checks.sh" plan)
grep -Fq 'required_checks_plan=ready' <<<"$plan_output"
grep -Fq 'repository=shared-host-automation protected=false' <<<"$plan_output"

if bash "$repository_root/scripts/github/reconcile-required-checks.sh" apply WRONG >/dev/null 2>&1; then
  printf 'Apply accepted an invalid confirmation\n' >&2
  exit 1
fi

apply_output=$(bash "$repository_root/scripts/github/reconcile-required-checks.sh" apply MIGRATE_REQUIRED_CHECKS_TO_JENKINS)
grep -Fq 'required_checks_apply=ready' <<<"$apply_output"
[[ $(wc -l < "$patch_log" | tr -d ' ') == 6 ]]
grep -Fq 'PATCH monitoring-stack-automation ["continuous-integration/jenkins"]' "$patch_log"
grep -Fq 'PUT shared-host-automation ["continuous-integration/jenkins"]' "$patch_log"

: > "$patch_log"
rollback_output=$(MOCK_CURRENT=jenkins MOCK_SHARED_PROTECTED=true bash "$repository_root/scripts/github/reconcile-required-checks.sh" rollback ROLLBACK_REQUIRED_CHECKS_FROM_JENKINS)
grep -Fq 'required_checks_rollback=ready' <<<"$rollback_output"
[[ $(wc -l < "$patch_log" | tr -d ' ') == 6 ]]
grep -Fq 'PATCH shared-host-automation ["validate"]' "$patch_log"

if MOCK_CURRENT=drift bash "$repository_root/scripts/github/reconcile-required-checks.sh" plan >/dev/null 2>&1; then
  printf 'Plan accepted unexpected required-check drift\n' >&2
  exit 1
fi

printf 'required_check_reconciliation_test=ready\n'