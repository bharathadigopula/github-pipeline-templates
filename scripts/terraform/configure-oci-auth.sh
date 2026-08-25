#!/usr/bin/env bash

#==============================================================================
# OCI API KEY AUTHENTICATION
#==============================================================================

set -euo pipefail

install -d -m 700 "$HOME/.oci"
printf '%s\n' "$OCI_PRIVATE_KEY" > "$HOME/.oci/api_key.pem"
chmod 600 "$HOME/.oci/api_key.pem"

{
  printf '[DEFAULT]\n'
  printf 'user=%s\n' "$OCI_USER_OCID"
  printf 'fingerprint=%s\n' "$OCI_FINGERPRINT"
  printf 'tenancy=%s\n' "$TF_VAR_tenancy_ocid"
  printf 'key_file=%s\n' "$HOME/.oci/api_key.pem"
} > "$HOME/.oci/config"

chmod 600 "$HOME/.oci/config"