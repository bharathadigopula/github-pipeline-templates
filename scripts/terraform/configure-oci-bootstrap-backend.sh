#!/usr/bin/env bash

#==============================================================================
# OCI BOOTSTRAP BACKEND CONFIGURATION
#==============================================================================

set -euo pipefail

working_directory=${1:?Missing Terraform working directory}
backend_key=${2:?Missing OCI backend key}
bucket=$(terraform -chdir="$working_directory" output -raw state_bucket_name)
namespace=$(terraform -chdir="$working_directory" output -raw object_storage_namespace)
region=$(terraform -chdir="$working_directory" output -raw region)

{
  printf 'terraform {\n'
  printf '  backend "oci" {}\n'
  printf '}\n'
} > "$working_directory/backend_override.tf"

{
  printf 'bucket = "%s"\n' "$bucket"
  printf 'namespace = "%s"\n' "$namespace"
  printf 'region = "%s"\n' "$region"
  printf 'key = "%s"\n' "$backend_key"
  printf 'config_file_profile = "DEFAULT"\n'
} > "$working_directory/backend.hcl"