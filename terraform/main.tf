# Azure DevOps + AWS Foundation - Main Configuration
# This configures the Terraform Cloud backend and required providers

terraform {
  required_version = ">= 1.0"

  # Terraform Cloud backend configuration
  cloud {
    organization = "mikestankavich"

    workspaces {
      name = "account-provisioning"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~> 0.10"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "bootstrap"
      ManagedBy   = "terraform"
      Repository  = "azdo-aws-demo"
    }
  }
}

# Azure DevOps Provider Configuration
provider "azuredevops" {
  org_service_url       = var.azdo_org_service_url
  personal_access_token = var.azdo_personal_access_token
}

# Random provider for generating unique resource names
provider "random" {}

# Generate random suffix for globally unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Local values for consistent naming
locals {
  # Resource tags
  common_tags = {
    Project     = var.project_name
    ManagedBy   = "terraform"
    Repository  = "azdo-aws-demo"
    CreatedBy   = "bootstrap-foundation"
  }
}
