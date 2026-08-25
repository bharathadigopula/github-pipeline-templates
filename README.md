# GitHub Pipeline Templates

Reusable GitHub Actions workflows and support scripts for infrastructure repositories. Consumers pin every workflow and script checkout to an immutable release tag so pipeline behaviour changes only through an explicit version update.

## Available Templates

| Workflow | Purpose |
|---|---|
| `.github/workflows/terraform-validate.yml` | Credential-free Terraform formatting, backend-disabled initialisation, and validation |
| `.github/workflows/terraform-oci-bootstrap.yml` | OCI bootstrap plan and optional exact saved-plan apply using either initial local state or an existing OCI Object Storage backend |
| `.github/workflows/terraform-oci.yml` | Remote-state OCI plan and optional exact saved-plan apply for established Terraform layers |

## Support Scripts

| Script | Purpose |
|---|---|
| `scripts/terraform/validate-oci-bootstrap-inputs.sh` | Validate operation and required OCI secret values |
| `scripts/terraform/validate-oci-terraform-inputs.sh` | Validate remote-state deployment operation and OCI secret values |
| `scripts/terraform/configure-oci-auth.sh` | Materialise a permission-restricted OCI runner profile from GitHub secrets |
| `scripts/terraform/create-terraform-plan.sh` | Create a saved plan and expose whether Terraform detected changes |
| `scripts/terraform/configure-oci-bootstrap-backend.sh` | Generate the temporary OCI backend declaration and partial backend configuration from Terraform outputs |
| `scripts/terraform/apply-oci-bootstrap-plan.sh` | Apply the saved plan, migrate initial local state when required, and verify state outputs |
| `scripts/terraform/apply-terraform-plan.sh` | Apply an exact saved plan against remote state and verify state outputs |

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
| `working_directory` | Yes | None | Terraform bootstrap root directory |
| `template_ref` | Yes | None | Git tag or commit containing the support scripts |
| `terraform_version` | No | `1.15.9` | Terraform version with OCI backend support |
| `backend_key` | No | `bootstrap/prd/terraform.tfstate` | Object Storage key used after migration |
| `backend_config_file` | No | Empty | Backend configuration file, relative to the Terraform root, for an existing OCI backend |

The consuming private repository supplies these secrets with `secrets: inherit`:

| Secret | Purpose |
|---|---|
| `OCI_TENANCY_OCID` | OCI tenancy identifier and Terraform `tenancy_ocid` input |
| `OCI_USER_OCID` | OCI API signing user |
| `OCI_FINGERPRINT` | Registered API-key fingerprint |
| `OCI_PRIVATE_KEY` | PEM API signing private key |
| `BUDGET_ALERT_RECIPIENTS` | Optional comma-separated budget alert email recipients |

```yaml
jobs:
  bootstrap:
    uses: bharathadigopula/github-pipeline-templates/.github/workflows/terraform-oci-bootstrap.yml@v0.6.0
    with:
      operation: ${{ inputs.apply && 'apply' || 'plan' }}
      working_directory: bootstrap/prd
      template_ref: v0.6.0
      terraform_version: 1.15.9
      backend_key: bootstrap/prd/terraform.tfstate
      backend_config_file: backend.hcl.example
    secrets: inherit
    permissions:
      contents: read
```

For `plan` and `apply`, the workflow disables the setup-terraform command wrapper so native Terraform detailed exit codes remain available. Exit code `0` skips the Apply job. Exit code `2` uploads the saved plan and, when `operation` is `apply`, applies that exact saved plan, including any creates, updates, or destroys.

Leave `backend_config_file` empty only for the initial bootstrap. The root must expose `state_bucket_name`, `object_storage_namespace`, and `region` outputs so the Apply job can generate the temporary OCI backend configuration and migrate local state. After migration, commit a backend configuration file without credentials, set `backend_config_file`, and declare `backend "oci" {}` in the root. Subsequent Plan and Apply jobs then initialise directly against remote state and skip migration.

The consuming workflow can map a boolean manual-dispatch checkbox to `plan` or `apply`. The plan artifact is retained for one day, and OCI credentials remain scoped to Terraform execution steps.

The `validate` operation is credential-free. This repository calls it against `tests/fixtures/terraform-basic` with `template_ref: ${{ github.sha }}` so pull requests test the workflow and scripts at the candidate commit.

## OCI Deployment Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `operation` | Yes | None | `plan` or `apply` |
| `working_directory` | Yes | None | Terraform root directory |
| `template_ref` | Yes | None | Tag or commit containing the support scripts |
| `terraform_version` | No | `1.15.9` | Terraform version with OCI backend support |
| `backend_config_file` | No | `backend.hcl.example` | Backend configuration file relative to the Terraform root |

The OCI deployment workflow requires the four OCI secrets listed above. `SSH_ALLOWED_CIDR` is required only by roots that declare `ssh_allowed_cidr`, `SSH_PUBLIC_KEY` is required only by roots that declare `ssh_public_key`, and `BUDGET_ALERT_RECIPIENTS` is required only by roots that declare `budget_alert_recipients`.

```yaml
jobs:
  network:
    uses: bharathadigopula/github-pipeline-templates/.github/workflows/terraform-oci.yml@v0.6.0
    with:
      operation: ${{ inputs.apply && 'apply' || 'plan' }}
      working_directory: network/prd
      template_ref: v0.6.0
      terraform_version: 1.15.9
      backend_config_file: backend.hcl.example
    secrets: inherit
    permissions:
      contents: read
```

Both jobs initialise the configured OCI backend. An unchanged Plan skips Apply. A changed Plan is retained for one day and the checked Apply path applies that exact artifact.

## Release Policy

- Consumers use immutable release tags, never `main`.
- The workflow reference and `template_ref` must use the same release tag.
- Version tags cannot be updated or deleted.
- Changes to `main` require pull requests and successful template validation.
- Action dependencies are pinned to full commit SHAs and maintained by Dependabot.

Jenkins shared-library templates belong in a separate `jenkins-pipeline-templates` repository when that implementation begins.