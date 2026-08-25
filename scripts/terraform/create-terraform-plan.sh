#!/usr/bin/env bash

#==============================================================================
# TERRAFORM SAVED PLAN CREATION
#==============================================================================

set -euo pipefail

working_directory=${1:?Missing Terraform working directory}
plan_file=${2:?Missing Terraform plan file}
: "${GITHUB_OUTPUT:?Missing GitHub step output file}"

set +e
terraform -chdir="$working_directory" plan -detailed-exitcode -no-color -out="$plan_file"
plan_exit_code=$?
set -e

case "$plan_exit_code" in
  0)
    printf 'has_changes=false\n' >> "$GITHUB_OUTPUT"
    ;;
  2)
    printf 'has_changes=true\n' >> "$GITHUB_OUTPUT"
    terraform -chdir="$working_directory" show -no-color "$plan_file"
    ;;
  *)
    exit "$plan_exit_code"
    ;;
esac