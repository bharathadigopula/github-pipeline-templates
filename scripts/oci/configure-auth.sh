#!/usr/bin/env bash

#==============================================================================
# OCI AUTHENTICATION
#==============================================================================

set -euo pipefail

: "${OCI_FINGERPRINT:?OCI_FINGERPRINT is required}"
: "${OCI_PRIVATE_KEY:?OCI_PRIVATE_KEY is required}"
: "${OCI_REGION:?OCI_REGION is required}"
: "${OCI_TENANCY_OCID:?OCI_TENANCY_OCID is required}"
: "${OCI_USER_OCID:?OCI_USER_OCID is required}"

install -d -m 700 "$HOME/.oci"
printf '%s\n' "$OCI_PRIVATE_KEY" > "$HOME/.oci/api_key.pem"
chmod 600 "$HOME/.oci/api_key.pem"

{
  printf '[DEFAULT]\n'
  printf 'user=%s\n' "$OCI_USER_OCID"
  printf 'fingerprint=%s\n' "$OCI_FINGERPRINT"
  printf 'tenancy=%s\n' "$OCI_TENANCY_OCID"
  printf 'region=%s\n' "$OCI_REGION"
  printf 'key_file=%s\n' "$HOME/.oci/api_key.pem"
} > "$HOME/.oci/config"

chmod 600 "$HOME/.oci/config"