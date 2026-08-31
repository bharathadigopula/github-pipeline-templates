//==============================================================================
// GITHUB PIPELINE TEMPLATE VALIDATION
//==============================================================================

@Library('jenkins-pipeline-templates@v1.3.0') _

repositoryValidationPipeline(
    shellSearchPath: 'scripts',
    terraformDirectories: ['tests/fixtures/terraform-basic'],
    validationScript: 'tests/test-run-command-secret-order.sh',
    validateWorkflows: true
)