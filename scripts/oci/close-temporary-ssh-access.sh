#!/usr/bin/env bash

#==============================================================================
# TEMPORARY OCI SSH ACCESS CLEANUP
#==============================================================================

set -euo pipefail

: "${NSG_ID:?NSG_ID is required}"
: "${OCI_REGION:?OCI_REGION is required}"
: "${RULE_DESCRIPTION:?RULE_DESCRIPTION is required}"

if [[ -n "${RULE_ID:-}" ]]; then
  rule_ids=$(jq -cn --arg rule_id "$RULE_ID" '[$rule_id]')
else
  rule_ids=$(oci network nsg rules list \
    --all \
    --nsg-id "$NSG_ID" \
    --region "$OCI_REGION" | jq -c --arg description "$RULE_DESCRIPTION" '[.data[] | select(.description == $description) | .id]')
fi

if [[ $(jq 'length' <<< "$rule_ids") -eq 0 ]]; then
  printf 'No temporary SSH security rule requires cleanup.\n'
  exit 0
fi

oci network nsg rules remove \
  --nsg-id "$NSG_ID" \
  --region "$OCI_REGION" \
  --security-rule-ids "$rule_ids"