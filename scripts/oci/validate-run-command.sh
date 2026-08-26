#!/usr/bin/env bash

#==============================================================================
# OCI RUN COMMAND VALIDATION
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
  RUN_COMMAND_DISPLAY_NAME
  RUN_COMMAND_SCRIPT_PATH
  RUN_COMMAND_TARGETS
  RUN_COMMAND_TIMEOUT_SECONDS
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

if [[ ! "$RUN_COMMAND_DISPLAY_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$ ]]; then
  printf 'RUN_COMMAND_DISPLAY_NAME must use 1-64 safe name characters.\n' >&2
  exit 1
fi

if [[ ! "$RUN_COMMAND_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || (( RUN_COMMAND_TIMEOUT_SECONDS < 1 || RUN_COMMAND_TIMEOUT_SECONDS > 86400 )); then
  printf 'RUN_COMMAND_TIMEOUT_SECONDS must be between 1 and 86400.\n' >&2
  exit 1
fi

if [[ "$RUN_COMMAND_SCRIPT_PATH" = /* || "$RUN_COMMAND_SCRIPT_PATH" =~ (^|/)\.\.(/|$) ]]; then
  printf 'RUN_COMMAND_SCRIPT_PATH must be a repository-relative path without parent traversal.\n' >&2
  exit 1
fi

if [[ ! -f "$AUTOMATION_DIRECTORY/$RUN_COMMAND_SCRIPT_PATH" ]]; then
  printf 'Host script does not exist: %s\n' "$RUN_COMMAND_SCRIPT_PATH" >&2
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
    (.arguments | type == "array" and all(.[]; type == "string" and length <= 255))
  )
' <<< "$RUN_COMMAND_TARGETS" >/dev/null; then
  printf 'RUN_COMMAND_TARGETS must contain one to five valid target entries.\n' >&2
  exit 1
fi

bash -n "$AUTOMATION_DIRECTORY/$RUN_COMMAND_SCRIPT_PATH"