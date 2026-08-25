#==============================================================================
# TERRAFORM TEST CONFIGURATION
#==============================================================================

terraform {
  required_version = ">= 1.5.0, < 2.0.0"
}

#==============================================================================
# TEST INPUT
#==============================================================================

variable "example_name" {
  description = "Name returned by the validation fixture."
  type        = string
  default     = "pipeline-template"
}

#==============================================================================
# TEST OUTPUT
#==============================================================================

output "example_name" {
  description = "Name proving the fixture is a valid Terraform configuration."
  value       = var.example_name
}