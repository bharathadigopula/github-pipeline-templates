#!/usr/bin/env bash

#==============================================================================
# OCI RUN COMMAND SECRET ORDER TEST
#==============================================================================

#==============================================================================
# SHELL SAFETY
#==============================================================================

set -euo pipefail

#==============================================================================
# TEST ENVIRONMENT
#==============================================================================

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT
mkdir -p "$temporary_root/automation" "$temporary_root/bin" "$temporary_root/results"
printf 'printf '\''test_marker=ready\\n'\''\n' > "$temporary_root/automation/bootstrap.sh"

#==============================================================================
# OCI CLI TEST DOUBLE
#==============================================================================

cat > "$temporary_root/bin/oci" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1 $2 $3" == "vault secret list" ]]; then
  if [[ "$*" == *"primary-name"* ]]; then
    printf '{"data":[{"id":"ocid1.vaultsecret.oc1.primary","secret-name":"primary-name","lifecycle-state":"ACTIVE"}]}\n'
  elif [[ "$*" == *"additional-name"* ]]; then
    printf '{"data":[{"id":"ocid1.vaultsecret.oc1.additional","secret-name":"additional-name","lifecycle-state":"ACTIVE"}]}\n'
  else
    printf '{"data":[]}\n'
  fi
elif [[ "$1 $2 $3" == "secrets secret-bundle get" ]]; then
  if [[ "$*" == *"ocid1.vaultsecret.oc1.primary"* ]]; then
    printf '{"data":{"secret-bundle-content":{"content":"cHJpbWFyeS1zZWNyZXQ="}}}\n'
  elif [[ "$*" == *"ocid1.vaultsecret.oc1.additional"* ]]; then
    printf '{"data":{"secret-bundle-content":{"content":"YWRkaXRpb25hbC1zZWNyZXQ="}}}\n'
  else
    exit 1
  fi
elif [[ "$1 $2 $3" == "instance-agent command create" ]]; then
  shift 3
  while (( $# > 0 )); do
    if [[ "$1" == "--content" ]]; then
      printf '%s\n' "$2" > "$CAPTURED_CONTENT"
      break
    fi
    shift
  done
  printf '{"data":{"id":"ocid1.instanceagentcommand.oc1.test"}}\n'
elif [[ "$1 $2 $3" == "instance-agent command-execution get" ]]; then
  printf '{"data":{"lifecycle-state":"SUCCEEDED","content":{"text":"test_marker=ready"}}}\n'
else
  printf 'Unexpected OCI command.\n' >&2
  exit 1
fi
MOCK
chmod +x "$temporary_root/bin/oci"

#==============================================================================
# RUN COMMAND EXECUTION
#==============================================================================

export AUTOMATION_DIRECTORY="$temporary_root/automation"
export CAPTURED_CONTENT="$temporary_root/content.json"
export GITHUB_ENV="$temporary_root/github.env"
export OCI_COMPARTMENT_OCID="ocid1.compartment.oc1..test"
export OCI_REGION="ap-hyderabad-1"
export RUN_COMMAND_ADDITIONAL_VAULT_SECRET_NAME="additional-name"
export RUN_COMMAND_DISPLAY_NAME="secret-order"
export RUN_COMMAND_REQUIRED_OUTPUT_MARKER="test_marker=ready"
export RUN_COMMAND_RESULTS_DIRECTORY="$temporary_root/results"
export RUN_COMMAND_SCRIPT_PATH="bootstrap.sh"
export RUN_COMMAND_TARGETS='[{"name":"target","instance_id":"ocid1.instance.oc1.ap-hyderabad-1.test","arguments":["base"]}]'
export RUN_COMMAND_TIMEOUT_SECONDS=30
export RUN_COMMAND_VAULT_SECRET_NAME="primary-name"
export PATH="$temporary_root/bin:$PATH"

bash "$repository_root/scripts/oci/load-vault-secret-argument.sh"
while IFS='=' read -r variable_name variable_value; do
  export "$variable_name=$variable_value"
done < "$GITHUB_ENV"
bash "$repository_root/scripts/oci/execute-run-command.sh"

#==============================================================================
# ARGUMENT ORDER ASSERTION
#==============================================================================

command_text=$(jq -r '.source.text' "$CAPTURED_CONTENT")
expected_line="set -- 'base' 'primary-secret' 'additional-secret'"
if [[ "${command_text%%$'\n'*}" != "$expected_line" ]]; then
  printf 'Run Command secret arguments were appended in the wrong order.\n' >&2
  exit 1
fi

printf 'run_command_secret_order=ready\n'
