# Azure DevOps + AWS Foundation - Variables
# Input variables for the bootstrap infrastructure

# =============================================================================
# Project Configuration
# =============================================================================

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "azdo-aws-demo"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod, demo)"
  type        = string
  default     = "demo"

  validation {
    condition     = contains(["dev", "staging", "prod", "demo"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, demo."
  }
}

# =============================================================================
# AWS Configuration
# =============================================================================

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-west-2"
}

variable "aws_account_id" {
  description = "AWS Account ID (for IAM trust relationships)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS Account ID must be exactly 12 digits."
  }
}

# =============================================================================
# Azure DevOps Configuration
# =============================================================================

variable "azdo_org_service_url" {
  description = "Azure DevOps organization URL"
  type        = string

  validation {
    condition     = can(regex("^https://dev\\.azure\\.com/[a-zA-Z0-9-]+$", var.azdo_org_service_url))
    error_message = "Azure DevOps URL must be in format: https://dev.azure.com/org-name"
  }
}

variable "azdo_personal_access_token" {
  description = "Azure DevOps Personal Access Token"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.azdo_personal_access_token) > 20
    error_message = "Personal Access Token appears to be invalid (too short)."
  }
}

variable "azdo_project_bootstrap" {
  description = "Name of the bootstrap infrastructure project"
  type        = string
  default     = "bootstrap-infrastructure"
}

variable "azdo_project_demo" {
  description = "Name of the demo application project"
  type        = string
  default     = "demo-application"
}

# =============================================================================
# Team Access Configuration
# =============================================================================

variable "team_members" {
  description = "List of team members to invite to Azure DevOps projects"
  type = list(object({
    email = string
    role  = string
  }))
  default = []

  validation {
    condition = alltrue([
      for member in var.team_members :
      contains(["developer", "devops", "manager", "reader"], member.role)
    ])
    error_message = "Team member roles must be one of: developer, devops, manager, reader."
  }
}

# =============================================================================
# Development and Debugging
# =============================================================================

variable "debug_mode" {
  description = "Enable additional logging and debugging resources"
  type        = bool
  default     = false
}

variable "resource_name_suffix" {
  description = "Additional suffix for resource names (useful for testing)"
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-z0-9-]*$", var.resource_name_suffix))
    error_message = "Resource name suffix must contain only lowercase letters, numbers, and hyphens."
  }
}