#!/usr/bin/env bash

#==============================================================================
# OCI BOOTSTRAP SAVED PLAN APPLY
#==============================================================================

set -euo pipefail

working_directory=${1:?Missing Terraform working directory}
backend_key=${2:?Missing OCI backend key}
plan_file=${3:?Missing Terraform plan file}
script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

terraform -chdir="$working_directory" apply -no-color -auto-approve "$plan_file"
bash "$script_directory/configure-oci-bootstrap-backend.sh" "$working_directory" "$backend_key"
terraform -chdir="$working_directory" init -migrate-state -force-copy -input=false -backend-config=backend.hcl
terraform -chdir="$working_directory" state list
terraform -chdir="$working_directory" output -no-color