#!/usr/bin/env bash

#==============================================================================
# VERSIONED SSH COMMAND EXECUTION
#==============================================================================

set -euo pipefail

: "${AUTOMATION_DIRECTORY:?AUTOMATION_DIRECTORY is required}"
: "${OCI_COMPARTMENT_OCID:?OCI_COMPARTMENT_OCID is required}"
: "${OCI_REGION:?OCI_REGION is required}"
: "${REQUIRED_OUTPUT_MARKER:?REQUIRED_OUTPUT_MARKER is required}"
: "${SSH_COMMAND_RESULTS_DIRECTORY:?SSH_COMMAND_RESULTS_DIRECTORY is required}"
: "${SSH_COMMAND_SCRIPT_PATH:?SSH_COMMAND_SCRIPT_PATH is required}"
: "${SSH_COMMAND_TARGETS:?SSH_COMMAND_TARGETS is required}"

mkdir -p "$SSH_COMMAND_RESULTS_DIRECTORY"

while IFS= read -r target; do
  target_name=$(jq -r '.name' <<< "$target")
  instance_id=$(jq -r '.instance_id' <<< "$target")
  ssh_user=$(jq -r '.ssh_user' <<< "$target")
  mapfile -t arguments < <(jq -r '.arguments[]' <<< "$target")
  instance=$(oci compute instance get --instance-id "$instance_id" --region "$OCI_REGION")
  authorized_keys=$(jq -r '.data.metadata.ssh_authorized_keys // ""' <<< "$instance")
  deployed_fingerprint=$(ssh-keygen -lf <(printf '%s\n' "$authorized_keys") | awk '{ print $2 }')
  supplied_fingerprint=$(ssh-keygen -y -f "$HOME/.ssh/host_key" | ssh-keygen -lf - | awk '{ print $2 }')

  if [[ "$deployed_fingerprint" != "$supplied_fingerprint" ]]; then
    printf 'The supplied SSH key does not match target %s.\n' "$target_name" >&2
    exit 1
  fi

  public_ip=$(oci compute instance list-vnics \
    --all \
    --compartment-id "$OCI_COMPARTMENT_OCID" \
    --instance-id "$instance_id" \
    --region "$OCI_REGION" | jq -r '[.data[] | select(."is-primary" == true)][0]."public-ip" // empty')

  if [[ -z "$public_ip" ]]; then
    printf 'No primary public IP was found for target %s.\n' "$target_name" >&2
    exit 1
  fi

  result_file="$SSH_COMMAND_RESULTS_DIRECTORY/${target_name}.log"
  ssh \
    -i "$HOME/.ssh/host_key" \
    -o BatchMode=yes \
    -o ConnectTimeout=20 \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=accept-new \
    "$ssh_user@$public_ip" \
    bash -s -- "${arguments[@]}" < "$AUTOMATION_DIRECTORY/$SSH_COMMAND_SCRIPT_PATH" | tee "$result_file"

  if ! grep -Fq "$REQUIRED_OUTPUT_MARKER" "$result_file"; then
    printf 'Required output marker is missing for target %s.\n' "$target_name" >&2
    exit 1
  fi
done < <(jq -c '.[]' <<< "$SSH_COMMAND_TARGETS")