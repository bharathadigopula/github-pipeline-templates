<!--
==============================================================================
GITHUB PIPELINE TEMPLATES
==============================================================================
-->

# GitHub Pipeline Templates

Reusable GitHub Actions workflows and support scripts for infrastructure repositories. Consumers pin every workflow and script checkout to an immutable release tag so pipeline behaviour changes only through an explicit version update.

<!--
==============================================================================
AVAILABLE TEMPLATES
==============================================================================
-->

## Available Templates

| Workflow | Purpose |
|---|---|
| `.github/workflows/terraform-validate.yml` | Credential-free Terraform formatting, backend-disabled initialisation, and validation |
| `.github/workflows/terraform-oci-bootstrap.yml` | OCI bootstrap plan and optional exact saved-plan apply using either initial local state or an existing OCI Object Storage backend |
| `.github/workflows/terraform-oci.yml` | Remote-state OCI plan and optional exact saved-plan apply for established Terraform layers |
| `.github/workflows/oci-run-command.yml` | Execute versioned host automation on up to five OCI instances with up to two ordered OCI Vault secret arguments |

<!--
==============================================================================
SUPPORT SCRIPTS
==============================================================================
-->

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
| `scripts/oci/validate-run-command.sh` | Validate immutable references, target JSON, timeouts, and the selected automation script |
| `scripts/oci/install-cli.sh` | Install the pinned OCI CLI used by Run Command jobs |
| `scripts/oci/configure-auth.sh` | Materialise the OCI runner profile used by Run Command jobs |
| `scripts/oci/load-vault-secret-argument.sh` | Retrieve, mask, and export one or two active OCI Vault secrets as ordered protected arguments |
| `scripts/oci/execute-run-command.sh` | Render, dispatch, monitor, and verify OCI Run Command executions |

Reusable workflows check out the consumer repository by default. The OCI bootstrap workflow therefore checks out this template repository separately at `template_ref` into `.pipeline-templates` before invoking its scripts.

<!--
==============================================================================
TERRAFORM VALIDATION INPUTS
==============================================================================
-->

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

<!--
==============================================================================
OCI BOOTSTRAP INPUTS
==============================================================================
-->

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

<!--
==============================================================================
OCI DEPLOYMENT INPUTS
==============================================================================
-->

## OCI Deployment Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `operation` | Yes | None | `plan` or `apply` |
| `working_directory` | Yes | None | Terraform root directory |
| `template_ref` | Yes | None | Tag or commit containing the support scripts |
| `terraform_version` | No | `1.15.9` | Terraform version with OCI backend support |
| `backend_config_file` | No | `backend.hcl.example` | Backend configuration file relative to the Terraform root |
| `cloudflare_account_id` | No | Empty | Cloudflare account identifier exposed as `TF_VAR_cloudflare_account_id` for roots that manage Cloudflare resources |

The OCI deployment workflow requires the four OCI secrets listed above. `SSH_ALLOWED_CIDR` is required only by roots that declare `ssh_allowed_cidr`, `SSH_PUBLIC_KEY` is required only by roots that declare `ssh_public_key`, and `BUDGET_ALERT_RECIPIENTS` is required only by roots that declare `budget_alert_recipients`. Roots that use the Cloudflare provider pass `CLOUDFLARE_API_TOKEN`; roots that create Jenkins credentials pass `JENKINS_GITHUB_TOKEN`; roots that create the Alertmanager SMTP Vault secret pass `MONITORING_SMTP_APP_PASSWORD`. The workflow exposes these only in Plan and Apply as provider environment variables or sensitive Terraform variables.

| Optional secret | Terraform or provider input |
|---|---|
| `CLOUDFLARE_API_TOKEN` | `CLOUDFLARE_API_TOKEN` |
| `JENKINS_GITHUB_TOKEN` | `TF_VAR_jenkins_github_token` |
| `MONITORING_SMTP_APP_PASSWORD` | `TF_VAR_monitoring_smtp_app_password` |

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

<!--
==============================================================================
OCI RUN COMMAND INPUTS
==============================================================================
-->

## OCI Run Command Inputs

The Run Command workflow checks out an immutable host-automation release, validates its script locally, and submits the rendered script through the OCI Instance Agent. No inbound SSH session is required.

| Input | Required | Default | Description |
|---|---:|---|---|
| `automation_repository` | Yes | None | Public repository containing the host script |
| `automation_ref` | Yes | None | Immutable semantic version tag for host automation |
| `template_ref` | Yes | None | Immutable semantic version tag for these support scripts |
| `compartment_ocid` | Yes | None | OCI compartment containing target instances |
| `display_name` | Yes | None | Safe name used for commands and result artifacts |
| `region` | Yes | None | OCI region containing targets and optional Vault secret |
| `required_output_marker` | No | Empty | Text that every successful target must emit |
| `script_path` | Yes | None | Repository-relative Bash script path |
| `targets_json` | Yes | None | JSON array of one to five target names, instance OCIDs, and argument arrays |
| `timeout_seconds` | No | `300` | Per-instance OCI command timeout, from 1 to 86,400 seconds |
| `vault_secret_name` | No | Empty | Primary active OCI Vault secret appended after the configured target arguments |
| `additional_vault_secret_name` | No | Empty | Second active OCI Vault secret appended after the primary secret |

```yaml
jobs:
  configure:
    uses: bharathadigopula/github-pipeline-templates/.github/workflows/oci-run-command.yml@v0.8.9
    with:
      automation_repository: bharathadigopula/shared-host-automation
      automation_ref: v0.3.1
      compartment_ocid: ${{ needs.prepare.outputs.compartment_ocid }}
      display_name: cloudflare-tunnel
      region: ap-hyderabad-1
      required_output_marker: cloudflare_tunnel=ready
      script_path: scripts/linux/cloudflare/bootstrap-cloudflared.sh
      targets_json: ${{ needs.prepare.outputs.connector_targets }}
      timeout_seconds: 300
      vault_secret_name: bharathcloudops-prd-hyd-cloudflare-tunnel-token
      template_ref: v0.8.9
    secrets: inherit
    permissions:
      contents: read
```

`automation_ref` and `template_ref` must be semantic version tags. Each target argument is limited to 255 characters, and the complete rendered inline command must not exceed OCI's 4,096-byte limit.

For each configured Vault name, the workflow requires exactly one matching active secret. It reads the current bundle, base64-decodes the content, rejects empty, multiline, or values longer than 255 characters, and masks the result. The primary value is appended first and the additional value second; neither value is placed in `targets_json` or uploaded as an artifact.

The workflow uploads per-target command results for seven days. A target succeeds only when OCI reports `SUCCEEDED` and, when configured, the required output marker appears in its output.

<!--
==============================================================================
TEMPLATE VALIDATION
==============================================================================
-->

## Validation

```shell
bash tests/test-run-command-secret-order.sh
SEARCH_PATH=scripts bash scripts/validation/validate-shell.sh
terraform -chdir=tests/fixtures/terraform-basic init -backend=false -input=false
terraform -chdir=tests/fixtures/terraform-basic validate -no-color
```

The Run Command regression test uses an OCI CLI test double to resolve two independent Vault bundles and assert the final order: target arguments, primary secret, additional secret.

<!--
==============================================================================
RELEASE POLICY
==============================================================================
-->

## Release Policy

- Consumers use immutable release tags, never `main`.
- The workflow reference and `template_ref` must use the same release tag.
- Version tags cannot be updated or deleted.
- Changes to `main` require pull requests and successful template validation.
- Action dependencies are pinned to full commit SHAs and maintained by Dependabot.

Jenkins shared-library templates belong in a separate `jenkins-pipeline-templates` repository when that implementation begins.