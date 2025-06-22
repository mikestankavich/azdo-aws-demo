# Azure DevOps + AWS Foundation - Outputs
# Export important values for next steps after pre-bootstrap

# =============================================================================
# AWS Infrastructure Outputs
# =============================================================================

output "aws_account_id" {
  description = "AWS Account ID where resources were created"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region where resources were deployed"
  value       = var.aws_region
}

# =============================================================================
# IAM Role Outputs (for Azure DevOps Service Connections)
# =============================================================================

output "azdo_terraform_role_arn" {
  description = "ARN of the IAM role for Azure DevOps Terraform operations"
  value       = aws_iam_role.azdo_terraform.arn
}

output "azdo_deployment_role_arn" {
  description = "ARN of the IAM role for Azure DevOps application deployments"
  value       = aws_iam_role.azdo_deployment.arn
}

output "azdo_readonly_role_arn" {
  description = "ARN of the IAM role for Azure DevOps read-only access"
  value       = aws_iam_role.azdo_readonly.arn
}

output "external_id" {
  description = "External ID for IAM role trust relationships"
  value       = random_string.external_id.result
  sensitive   = true
}

# =============================================================================
# State Backend Outputs
# =============================================================================

output "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state storage"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_bucket_arn" {
  description = "S3 bucket ARN for Terraform state storage"
  value       = aws_s3_bucket.terraform_state.arn
}

output "terraform_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  value       = aws_dynamodb_table.terraform_lock.name
}

output "terraform_lock_table_arn" {
  description = "DynamoDB table ARN for Terraform state locking"
  value       = aws_dynamodb_table.terraform_lock.arn
}

# =============================================================================
# Azure DevOps Project Outputs
# =============================================================================

output "azdo_project_shared_infra_id" {
  description = "Azure DevOps shared infra project ID"
  value       = azuredevops_project.shared_infra.id
}

output "azdo_project_shared_infra_url" {
  description = "Azure DevOps shared infra project URL"
  value       = "${var.azdo_org_service_url}/${azuredevops_project.shared_infra.name}"
}

output "azdo_project_demo_id" {
  description = "Azure DevOps demo application project ID"
  value       = azuredevops_project.demo.id
}

output "azdo_project_demo_url" {
  description = "Azure DevOps demo application project URL"
  value       = "${var.azdo_org_service_url}/${azuredevops_project.demo.name}"
}

# =============================================================================
# Shared Infra Pipeline Information
# =============================================================================

output "shared_infra_pipeline_name" {
  description = "Name of the shared infra pipeline to run next"
  value       = azuredevops_build_definition.shared_infra_pipeline.name
}

output "shared_infra_pipeline_url" {
  description = "URL to the shared infra pipeline"
  value       = "${var.azdo_org_service_url}/${azuredevops_project.shared_infra.name}/_build?definitionId=${azuredevops_build_definition.shared_infra_pipeline.id}"
}

# =============================================================================
# Next Steps Summary
# =============================================================================

output "next_steps" {
  description = "Next steps after pre-bootstrap completion"
  value = {
    step_1 = "Clone repositories: ${azuredevops_project.shared_infra.name} and ${azuredevops_project.demo.name}"
    step_2 = "Add Terraform code and pipeline YAML to shared infra repository"
    step_3 = "Configure AWS service connections in Azure DevOps using the provided role ARNs"
    step_4 = "Run the '${azuredevops_build_definition.shared_infra_pipeline.name}' pipeline"
    step_5 = "Continue with shared modules and demo application development"

    repositories = {
      infra_repo = "${var.azdo_org_service_url}/${azuredevops_project.shared_infra.name}/_git/${data.azuredevops_git_repository.shared_infra_repo.name}"
      demo_repo      = "${var.azdo_org_service_url}/${azuredevops_project.demo.name}/_git/${data.azuredevops_git_repository.demo_repo.name}"
    }

    service_connections = {
      terraform_role  = aws_iam_role.azdo_terraform.arn
      deployment_role = aws_iam_role.azdo_deployment.arn
      readonly_role   = aws_iam_role.azdo_readonly.arn
      external_id     = "Use the external_id output (marked sensitive)"
    }
  }
}