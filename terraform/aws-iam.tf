# Azure DevOps + AWS Foundation - IAM Configuration
# Creates IAM roles and policies for Azure DevOps integration

# =============================================================================
# Data Sources
# =============================================================================

data "aws_caller_identity" "current" {}

# External ID for added security in cross-account trust
resource "random_string" "external_id" {
  length  = 32
  special = true
}

# =============================================================================
# IAM Role for Terraform Operations
# =============================================================================

# IAM role for Terraform operations (broad permissions for infrastructure management)
resource "aws_iam_role" "azdo_terraform" {
  name                = "${var.project_name}-terraform-role"
  max_session_duration = 3600  # 1 hour

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = random_string.external_id.result
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-terraform-role"
    Purpose     = "terraform-operations"
    AccessLevel = "admin"
  })
}

# Policy for Terraform operations (comprehensive AWS access)
data "aws_iam_policy_document" "azdo_terraform_policy" {
  # EC2 and VPC management
  statement {
    effect = "Allow"
    actions = [
      "ec2:*",
      "vpc:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "route53:*",
      "acm:*"
    ]
    resources = ["*"]
  }

  # ECS and container services
  statement {
    effect = "Allow"
    actions = [
      "ecs:*",
      "ecr:*",
      "logs:*",
      "application-autoscaling:*"
    ]
    resources = ["*"]
  }

  # IAM management (limited to specific paths)
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${var.project_name}-*"
    ]
  }

  # IAM policy management
  statement {
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.project_name}-*"
    ]
  }

  # S3 management
  statement {
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = [
      "arn:aws:s3:::${var.project_name}-*",
      "arn:aws:s3:::${var.project_name}-*/*"
    ]
  }

  # Secrets Manager and Parameter Store
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:*",
      "ssm:*"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/*",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*"
    ]
  }

  # CloudWatch and monitoring
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:*",
      "logs:*",
      "xray:*"
    ]
    resources = ["*"]
  }

  # Additional AWS services
  statement {
    effect = "Allow"
    actions = [
      "cloudtrail:*",
      "config:*",
      "sns:*",
      "sqs:*",
      "dynamodb:*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "azdo_terraform" {
  name   = "${var.project_name}-terraform-policy"
  role   = aws_iam_role.azdo_terraform.id
  policy = data.aws_iam_policy_document.azdo_terraform_policy.json
}

# =============================================================================
# IAM Role for Application Deployment
# =============================================================================

# IAM role for application deployment (limited permissions)
resource "aws_iam_role" "azdo_deployment" {
  name                = "${var.project_name}-deployment-role"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = random_string.external_id.result
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-deployment-role"
    Purpose     = "application-deployment"
    AccessLevel = "limited"
  })
}

# Policy for application deployment (ECS, ECR, logs)
data "aws_iam_policy_document" "azdo_deployment_policy" {
  # ECS deployment permissions
  statement {
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:DescribeTasks",
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:ListTasks"
    ]
    resources = [
      "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${var.project_name}-*",
      "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${var.project_name}-*"
    ]
  }

  # ECR permissions for image management
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}-*"
    ]
  }

  # ECR token permission (account level)
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  # CloudWatch logs for deployment monitoring
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ecs/${var.project_name}-*"
    ]
  }

  # Secrets Manager read access
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/*"
    ]
  }

  # SSM Parameter Store read access
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*"
    ]
  }
}

resource "aws_iam_role_policy" "azdo_deployment" {
  name   = "${var.project_name}-deployment-policy"
  role   = aws_iam_role.azdo_deployment.id
  policy = data.aws_iam_policy_document.azdo_deployment_policy.json
}

# =============================================================================
# IAM Role for Read-Only Access
# =============================================================================

# IAM role for read-only access
resource "aws_iam_role" "azdo_readonly" {
  name                = "${var.project_name}-readonly-role"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = random_string.external_id.result
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-readonly-role"
    Purpose     = "monitoring-readonly"
    AccessLevel = "readonly"
  })
}

# Attach AWS managed ReadOnlyAccess policy
resource "aws_iam_role_policy_attachment" "azdo_readonly" {
  role       = aws_iam_role.azdo_readonly.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}