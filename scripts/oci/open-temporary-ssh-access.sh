#!/usr/bin/env bash

#==============================================================================
# TEMPORARY OCI SSH ACCESS
#==============================================================================

set -euo pipefail

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
: "${GITHUB_RUN_ATTEMPT:?GITHUB_RUN_ATTEMPT is required}"
: "${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"
: "${OCI_COMPARTMENT_OCID:?OCI_COMPARTMENT_OCID is required}"
: "${OCI_REGION:?OCI_REGION is required}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${SSH_COMMAND_DISPLAY_NAME:?SSH_COMMAND_DISPLAY_NAME is required}"
: "${SSH_COMMAND_TARGETS:?SSH_COMMAND_TARGETS is required}"

target_count=$(jq 'length' <<< "$SSH_COMMAND_TARGETS")
nsg_candidates="$RUNNER_TEMP/nsg-candidates"
: > "$nsg_candidates"

while IFS= read -r instance_id; do
  oci compute instance list-vnics \
    --all \
    --compartment-id "$OCI_COMPARTMENT_OCID" \
    --instance-id "$instance_id" \
    --region "$OCI_REGION" | jq -r '.data[] | select(."is-primary" == true) | ."nsg-ids"[]' >> "$nsg_candidates"
done < <(jq -r '.[].instance_id' <<< "$SSH_COMMAND_TARGETS")

server_nsg_id=$(sort "$nsg_candidates" | uniq -c | awk -v target_count="$target_count" '$1 == target_count { print $2 }')
if [[ $(wc -w <<< "$server_nsg_id") -ne 1 ]]; then
  printf 'Unable to identify one NSG shared by every target.\n' >&2
  exit 1
fi

runner_ip=$(curl --fail --silent --show-error https://api.ipify.org)
if [[ ! "$runner_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  printf 'Unable to resolve the GitHub runner IPv4 address.\n' >&2
  exit 1
fi

description="${SSH_COMMAND_DISPLAY_NAME}-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"
{
  printf 'description=%s\n' "$description"
  printf 'nsg_id=%s\n' "$server_nsg_id"
} >> "$GITHUB_OUTPUT"

rules=$(jq -n \
  --arg description "$description" \
  --arg source "$runner_ip/32" \
  '[{direction: "INGRESS", protocol: "6", source: $source, sourceType: "CIDR_BLOCK", isStateless: false, description: $description, tcpOptions: {destinationPortRange: {min: 22, max: 22}}}]')
response=$(oci network nsg rules add \
  --nsg-id "$server_nsg_id" \
  --region "$OCI_REGION" \
  --security-rules "$rules")
rule_id=$(jq -r '.data[0].id // empty' <<< "$response")

if [[ -z "$rule_id" ]]; then
  printf 'OCI did not return the temporary SSH security rule ID.\n' >&2
  exit 1
fi

printf 'rule_id=%s\n' "$rule_id" >> "$GITHUB_OUTPUT"