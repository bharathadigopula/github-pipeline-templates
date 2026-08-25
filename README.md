# GitHub Pipeline Templates

Reusable GitHub Actions workflows and support scripts for infrastructure repositories. Consumers pin every workflow and script checkout to an immutable release tag so pipeline behaviour changes only through an explicit version update.

## Available Templates

| Workflow | Purpose |
|---|---|
| `.github/workflows/terraform-validate.yml` | Credential-free Terraform formatting, backend-disabled initialisation, and validation |
| `.github/workflows/terraform-oci-bootstrap.yml` | OCI bootstrap plan, issue approval, exact saved-plan apply, and migration from local runner state to an OCI Object Storage backend |

## Support Scripts

| Script | Purpose |
|---|---|
| `scripts/terraform/validate-oci-bootstrap-inputs.sh` | Validate operation and required OCI secret values |
| `scripts/terraform/configure-oci-auth.sh` | Materialise a permission-restricted OCI runner profile from GitHub secrets |
| `scripts/terraform/create-terraform-plan.sh` | Create a saved plan and expose whether Terraform detected changes |
| `scripts/terraform/configure-oci-bootstrap-backend.sh` | Generate the temporary OCI backend declaration and partial backend configuration from Terraform outputs |
| `scripts/terraform/apply-oci-bootstrap-plan.sh` | Apply the approved saved plan, migrate state, and verify remote state outputs |

Reusable workflows check out the consumer repository by default. The OCI bootstrap workflow therefore checks out this template repository separately at `template_ref` into `.pipeline-templates` before invoking its scripts.

## Terraform Validation Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `working_directory` | Yes | None | Terraform root or module directory |
| `terraform_version` | No | `1.10.5` | Terraform CLI version used for validation |

```yaml
jobs:
  validate:
    uses: bharathadigopula/github-pipeline-templates/.github/workflows/terraform-validate.yml@v0.2.0
    with:
      working_directory: network/prd
      terraform_version: 1.15.9
    permissions:
      contents: read
```

The validation template never uses cloud credentials and never runs `terraform plan` or `terraform apply`.

## OCI Bootstrap Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `operation` | Yes | None | `validate`, `plan`, or `apply` |
| `approvers` | For apply | Empty | Comma-separated GitHub users allowed to approve changes |
| `minimum_approvals` | No | `1` | Number of approvals required before apply |
| `working_directory` | Yes | None | Terraform bootstrap root directory |
| `template_ref` | Yes | None | Git tag or commit containing the support scripts |
| `terraform_version` | No | `1.15.9` | Terraform version with OCI backend support |
| `backend_key` | No | `bootstrap/prd/terraform.tfstate` | Object Storage key used after migration |

The consuming private repository supplies these secrets with `secrets: inherit`:

| Secret | Purpose |
|---|---|
| `OCI_TENANCY_OCID` | OCI tenancy identifier and Terraform `tenancy_ocid` input |
| `OCI_USER_OCID` | OCI API signing user |
| `OCI_FINGERPRINT` | Registered API-key fingerprint |
| `OCI_PRIVATE_KEY` | PEM API signing private key |

```yaml
jobs:
  bootstrap:
    uses: bharathadigopula/github-pipeline-templates/.github/workflows/terraform-oci-bootstrap.yml@v0.3.0
    with:
      operation: apply
      approvers: bharathadigopula
      minimum_approvals: 1
      working_directory: bootstrap/prd
      template_ref: v0.3.0
      terraform_version: 1.15.9
      backend_key: bootstrap/prd/terraform.tfstate
    secrets: inherit
    permissions:
      contents: read
      issues: write
```

For `plan` and `apply`, the bootstrap root must expose `state_bucket_name`, `object_storage_namespace`, and `region` outputs. Terraform detailed exit code `0` skips approval and apply. Exit code `2` uploads the saved plan and, for `apply`, opens an approval issue. Approval applies that exact saved plan, including any creates, updates, or destroys, generates a temporary `backend "oci"` override after the bucket exists, migrates state with `terraform init -migrate-state`, and verifies the remote state.

The approval job receives `issues: write` only to create and monitor its approval issue. The plan artifact is retained for one day. OCI credentials are not available to the approval job.

The `validate` operation is credential-free. This repository calls it against `tests/fixtures/terraform-basic` with `template_ref: ${{ github.sha }}` so pull requests test the workflow and scripts at the candidate commit.

## Release Policy

- Consumers use immutable release tags, never `main`.
- The workflow reference and `template_ref` must use the same release tag.
- Version tags cannot be updated or deleted.
- Changes to `main` require pull requests and successful template validation.
- Action dependencies are pinned to full commit SHAs and maintained by Dependabot.

Jenkins shared-library templates belong in a separate `jenkins-pipeline-templates` repository when that implementation begins.