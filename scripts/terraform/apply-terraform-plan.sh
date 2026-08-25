#!/usr/bin/env bash

#==============================================================================
# TERRAFORM SAVED PLAN APPLY
#==============================================================================

set -euo pipefail

working_directory=${1:?Missing Terraform working directory}
plan_file=${2:?Missing Terraform plan file}

terraform -chdir="$working_directory" apply -no-color -auto-approve "$plan_file"
terraform -chdir="$working_directory" state list
terraform -chdir="$working_directory" output -no-color