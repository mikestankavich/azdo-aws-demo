# Azure DevOps + AWS Foundation - Azure DevOps Configuration
# Creates Azure DevOps projects and team access

# =============================================================================
# Azure DevOps Projects
# =============================================================================

# Shared Infrastructure Project
resource "azuredevops_project" "shared_infra" {
  name               = var.azdo_project_shared_infra
  description        = "Shared infrastructure modules and team setup for ${var.project_name}"
  visibility         = "private"
  version_control    = "Git"
  work_item_template = "Agile"

  features = {
    "boards"       = "enabled"
    "repositories" = "enabled"
    "pipelines"    = "enabled"
    "testplans"    = "disabled"
    "artifacts"    = "enabled"
  }
}

# Demo Application Project
resource "azuredevops_project" "demo" {
  name               = var.azdo_project_demo
  description        = "Demo application with CI/CD pipelines for ${var.project_name}"
  visibility         = "private"
  version_control    = "Git"
  work_item_template = "Agile"

  features = {
    "boards"       = "enabled"
    "repositories" = "enabled"
    "pipelines"    = "enabled"
    "testplans"    = "disabled"
    "artifacts"    = "enabled"
  }
}

# =============================================================================
# Git Repositories (Use Auto-Created Default Repositories)
# =============================================================================

# Reference the default repository created automatically with the shared-infra project
data "azuredevops_git_repository" "shared_infra_repo" {
  project_id = azuredevops_project.shared_infra.id
  name       = azuredevops_project.shared_infra.name
}

# Reference the default repository created automatically with the demo project
data "azuredevops_git_repository" "demo_repo" {
  project_id = azuredevops_project.demo.id
  name       = azuredevops_project.demo.name
}

# =============================================================================
# Variable Groups for Pipeline Configuration
# =============================================================================

# Shared variable group for AWS configuration and IAM roles
resource "azuredevops_variable_group" "aws_shared" {
  project_id   = azuredevops_project.shared_infra.id
  name         = "AWS-Foundation-Configuration"
  description  = "AWS configuration and IAM role ARNs for Azure DevOps integration"
  allow_access = true

  variable {
    name  = "AWS_REGION"
    value = var.aws_region
  }

  variable {
    name  = "AWS_ACCOUNT_ID"
    value = var.aws_account_id
  }

  variable {
    name  = "PROJECT_NAME"
    value = var.project_name
  }

  variable {
    name  = "TERRAFORM_ROLE_ARN"
    value = aws_iam_role.azdo_terraform.arn
  }

  variable {
    name  = "DEPLOYMENT_ROLE_ARN"
    value = aws_iam_role.azdo_deployment.arn
  }

  variable {
    name  = "READONLY_ROLE_ARN"
    value = aws_iam_role.azdo_readonly.arn
  }

  variable {
    name           = "EXTERNAL_ID"
    value          = random_string.external_id.result
    is_secret      = true
  }
}

# =============================================================================
# Team Access and Permissions (Simplified)
# =============================================================================

# Note: Team management will be handled by the shared-infra pipeline
# This pre-bootstrap only creates the foundation for team access

# =============================================================================
# Single Shared Infrastructure Pipeline
# =============================================================================

# Single shared-infra pipeline that creates state backend and shared infrastructure
resource "azuredevops_build_definition" "shared_infra_pipeline" {
  project_id = azuredevops_project.shared_infra.id
  name       = "01-Shared-Infra-Foundation"
  path       = "\\Foundation"

  ci_trigger {
    use_yaml = false  # Manual trigger initially
  }

  repository {
    repo_type   = "TfsGit"
    repo_id     = data.azuredevops_git_repository.shared_infra_repo.id
    branch_name = data.azuredevops_git_repository.shared_infra_repo.default_branch
    yml_path    = "pipelines/shared-infra-foundation.yml"
  }

  variable_groups = [
    azuredevops_variable_group.aws_shared.id
  ]

  variable {
    name  = "system.debug"
    value = var.debug_mode ? "true" : "false"
  }
}

# =============================================================================
# Next Steps Documentation
# =============================================================================

# Create a placeholder for next steps after bootstrap
locals {
  next_steps = {
    step_1 = "Clone Azure DevOps repositories locally"
    step_2 = "Add pipeline YAML files to shared-infra-infrastructure repo"
    step_3 = "Run '01-Shared-Infra' pipeline to create shared infra resources"
    step_4 = "Add shared modules and security baseline"
    step_5 = "Create demo application pipelines"

    repositories = {
      shared_infra = azuredevops_project.shared_infra.name
      demo      = azuredevops_project.demo.name
    }

    service_connections_needed = {
      terraform_role  = aws_iam_role.azdo_terraform.arn
      deployment_role = aws_iam_role.azdo_deployment.arn
      readonly_role   = aws_iam_role.azdo_readonly.arn
      external_id     = random_string.external_id.result
    }
  }
}

# =============================================================================
# Project Permissions (Minimal Setup)
# =============================================================================

# Note: Additional permissions and team management will be handled
# by the shared-infra pipeline after the initial foundation is created