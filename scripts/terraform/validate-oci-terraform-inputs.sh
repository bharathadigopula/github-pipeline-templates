#!/usr/bin/env bash

#==============================================================================
# OCI TERRAFORM INPUT VALIDATION
#==============================================================================

set -euo pipefail

[[ "${TF_OPERATION:-}" == "plan" || "${TF_OPERATION:-}" == "apply" ]]
: "${TF_VAR_tenancy_ocid:?Missing OCI_TENANCY_OCID}"
: "${OCI_USER_OCID:?Missing OCI_USER_OCID}"
: "${OCI_FINGERPRINT:?Missing OCI_FINGERPRINT}"
: "${OCI_PRIVATE_KEY:?Missing OCI_PRIVATE_KEY}"