//==============================================================================
// GITHUB PIPELINE TEMPLATE VALIDATION
//==============================================================================

@Library('jenkins-pipeline-templates@v1.4.0') _

repositoryValidationPipeline(
    githubRepository: 'bharathadigopula/github-pipeline-templates',
    shellSearchPath: 'scripts',
    terraformDirectories: ['tests/fixtures/terraform-basic'],
    validationScript: 'tests/test-run-command-secret-order.sh',
    validationCommands: ['bash tests/test-required-check-reconciliation.sh'],
    validateWorkflows: true
)