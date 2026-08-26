#!/usr/bin/env bash

#==============================================================================
# OCI SSH COMMAND VALIDATION
#==============================================================================

set -euo pipefail

required_variables=(
  AUTOMATION_DIRECTORY
  AUTOMATION_REF
  OCI_COMPARTMENT_OCID
  OCI_FINGERPRINT
  OCI_PRIVATE_KEY
  OCI_REGION
  OCI_TENANCY_OCID
  OCI_USER_OCID
  REQUIRED_OUTPUT_MARKER
  SSH_COMMAND_DISPLAY_NAME
  SSH_COMMAND_SCRIPT_PATH
  SSH_COMMAND_TARGETS
  SSH_PRIVATE_KEY
  TEMPLATE_REF
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    printf 'Required value %s is empty.\n' "$variable_name" >&2
    exit 1
  fi
done

for immutable_ref in "$AUTOMATION_REF" "$TEMPLATE_REF"; do
  if [[ ! "$immutable_ref" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Repository references must be immutable semantic version tags.\n' >&2
    exit 1
  fi
done

if [[ ! "$OCI_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]+$ ]]; then
  printf 'OCI_REGION must be an OCI region identifier.\n' >&2
  exit 1
fi

if [[ ! "$OCI_COMPARTMENT_OCID" =~ ^ocid1\.compartment\.oc1\.\.[a-z0-9]+$ ]]; then
  printf 'OCI_COMPARTMENT_OCID must be a compartment OCID.\n' >&2
  exit 1
fi

if [[ ! "$SSH_COMMAND_DISPLAY_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$ ]]; then
  printf 'SSH_COMMAND_DISPLAY_NAME must use 1-64 safe name characters.\n' >&2
  exit 1
fi

if [[ "$SSH_COMMAND_SCRIPT_PATH" = /* || "$SSH_COMMAND_SCRIPT_PATH" =~ (^|/)\.\.(/|$) ]]; then
  printf 'SSH_COMMAND_SCRIPT_PATH must be a repository-relative path without parent traversal.\n' >&2
  exit 1
fi

if [[ ! -f "$AUTOMATION_DIRECTORY/$SSH_COMMAND_SCRIPT_PATH" ]]; then
  printf 'Host script does not exist: %s\n' "$SSH_COMMAND_SCRIPT_PATH" >&2
  exit 1
fi

if ! jq -e '
  type == "array" and
  length > 0 and
  length <= 5 and
  all(.[];
    type == "object" and
    (.name | type == "string" and test("^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$")) and
    (.instance_id | type == "string" and test("^ocid1\\.instance\\.oc1\\.[a-z0-9.-]+$")) and
    (.ssh_user | type == "string" and test("^[a-z_][a-z0-9_-]{0,31}$")) and
    (.arguments | type == "array" and all(.[]; type == "string" and length <= 255))
  )
' <<< "$SSH_COMMAND_TARGETS" >/dev/null; then
  printf 'SSH_COMMAND_TARGETS must contain one to five valid target entries.\n' >&2
  exit 1
fi

bash -n "$AUTOMATION_DIRECTORY/$SSH_COMMAND_SCRIPT_PATH"