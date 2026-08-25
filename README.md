# GitHub Pipeline Templates 🔁

Reusable GitHub Actions workflows for infrastructure repositories. Consumers pin workflows to release tags so pipeline behaviour changes only through an explicit version update.

## Available Templates 📦

| Workflow | Purpose |
|---|---|
| `.github/workflows/terraform-validate.yml` | Credential-free Terraform formatting, backend-disabled initialisation, and validation |

## Terraform Dry Run 🔍

```yaml
jobs:
  validate:
    strategy:
      matrix:
        root:
          - network/prd
          - compute/prd
    uses: bharathadigopula/github-pipeline-templates/.github/workflows/terraform-validate.yml@v0.1.0
    with:
      working_directory: ${{ matrix.root }}
    permissions:
      contents: read
```

The template does not use cloud credentials and never runs `terraform plan` or `terraform apply`.

## Release Policy 🔒

- Consumers must use a release tag.
- Version tags cannot be updated or deleted.
- Changes to `main` require pull requests and successful template validation.

Jenkins shared-library templates belong in a separate `jenkins-pipeline-templates` repository when that implementation begins.