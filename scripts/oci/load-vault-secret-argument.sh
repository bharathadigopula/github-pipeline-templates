#!/usr/bin/env bash

#==============================================================================
# OCI VAULT SCRIPT ARGUMENT
#==============================================================================

set -euo pipefail

: "${GITHUB_ENV:?GITHUB_ENV is required}"
: "${OCI_COMPARTMENT_OCID:?OCI_COMPARTMENT_OCID is required}"
: "${OCI_REGION:?OCI_REGION is required}"

#==============================================================================
# VAULT SECRET RESOLUTION
#==============================================================================

load_secret() {
  local secret_name="$1"
  local output_variable="$2"
  local secret_response
  local secret_id
  local secret_value

  if [[ ! "$secret_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf '%s contains unsupported characters.\n' "$output_variable" >&2
    exit 1
  fi

  secret_response=$(oci vault secret list \
    --all \
    --compartment-id "$OCI_COMPARTMENT_OCID" \
    --name "$secret_name" \
    --region "$OCI_REGION")
  secret_id=$(jq -r --arg secret_name "$secret_name" '
    [.data[] | select(."secret-name" == $secret_name and ."lifecycle-state" == "ACTIVE")]
    | if length == 1 then .[0].id else empty end
  ' <<< "$secret_response")

  if [[ -z "$secret_id" ]]; then
    printf 'Expected exactly one active OCI Vault secret named %s.\n' "$secret_name" >&2
    exit 1
  fi

  secret_value=$(oci secrets secret-bundle get \
    --secret-id "$secret_id" \
    --stage CURRENT \
    --region "$OCI_REGION" \
    | jq -r '.data."secret-bundle-content".content' \
    | base64 --decode)

  if [[ -z "$secret_value" || ${#secret_value} -gt 255 || "$secret_value" == *$'\n'* || "$secret_value" == *$'\r'* ]]; then
    printf 'OCI Vault secret must contain one non-empty line of at most 255 characters.\n' >&2
    exit 1
  fi

  printf '::add-mask::%s\n' "$secret_value"
  printf '%s=%s\n' "$output_variable" "$secret_value" >> "$GITHUB_ENV"
}

#==============================================================================
# ORDERED SECRET ARGUMENTS
#==============================================================================

if [[ -n "${RUN_COMMAND_VAULT_SECRET_NAME:-}" ]]; then
  load_secret "$RUN_COMMAND_VAULT_SECRET_NAME" RUN_COMMAND_SECRET_ARGUMENT
fi

if [[ -n "${RUN_COMMAND_ADDITIONAL_VAULT_SECRET_NAME:-}" ]]; then
  load_secret "$RUN_COMMAND_ADDITIONAL_VAULT_SECRET_NAME" RUN_COMMAND_ADDITIONAL_SECRET_ARGUMENT
fi