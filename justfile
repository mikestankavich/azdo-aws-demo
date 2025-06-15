# Azure DevOps + AWS Foundation Automation
# Requires: just, direnv, terraform, aws cli

# Load environment variables from .env.local
set dotenv-load

# Default recipe - show available commands
default:
    @just --list

# =============================================================================
# Environment and Setup
# =============================================================================

# Validate environment configuration and tool dependencies
validate:
    #!/usr/bin/env bash
    echo "🔍 Validating environment and dependencies..."

    # Check required tools
    command -v terraform >/dev/null 2>&1 || { echo "❌ terraform not found"; exit 1; }
    command -v aws >/dev/null 2>&1 || { echo "❌ aws cli not found"; exit 1; }
    command -v direnv >/dev/null 2>&1 || { echo "❌ direnv not found"; exit 1; }

    # Check environment file exists
    if [ ! -f .env.local ]; then
        echo "❌ .env.local not found. Copy from .env.local.example and configure."
        exit 1
    fi

    # Check required environment variables
    : ${AWS_ACCESS_KEY_ID:?❌ AWS_ACCESS_KEY_ID not set}
    : ${AWS_SECRET_ACCESS_KEY:?❌ AWS_SECRET_ACCESS_KEY not set}
    : ${AZDO_ORG_SERVICE_URL:?❌ AZDO_ORG_SERVICE_URL not set}
    : ${AZDO_PERSONAL_ACCESS_TOKEN:?❌ AZDO_PERSONAL_ACCESS_TOKEN not set}

    # Test AWS connectivity
    echo "🔍 Testing AWS connectivity..."
    aws sts get-caller-identity --query 'Account' --output text || { echo "❌ AWS authentication failed"; exit 1; }

    # Validate Terraform configuration
    echo "🔍 Validating Terraform configuration..."
    cd terraform && terraform validate

    echo "✅ Environment validation complete!"

# Initialize development environment
setup:
    #!/usr/bin/env bash
    echo "🚀 Setting up development environment..."

    # Ensure .env.local exists
    if [ ! -f .env.local ]; then
        cp .env.local.example .env.local
        echo "📋 Created .env.local from template - please configure it!"
        exit 1
    fi

    # Initialize Terraform
    echo "🔧 Initializing Terraform..."
    cd terraform && terraform init

    # Install pre-commit hooks if available
    if command -v pre-commit >/dev/null 2>&1; then
        echo "🪝 Installing pre-commit hooks..."
        pre-commit install
    fi

    echo "✅ Development environment ready!"

# =============================================================================
# Terraform Operations
# =============================================================================

# Show planned infrastructure changes
plan:
    #!/usr/bin/env bash
    echo "📋 Planning infrastructure changes..."
    cd terraform
    terraform plan -detailed-exitcode

    if [ $? -eq 2 ]; then
        echo "📝 Changes detected - review plan above"
    else
        echo "✅ No changes needed"
    fi

# Apply infrastructure changes (interactive)
apply:
    #!/usr/bin/env bash
    echo "🚀 Applying infrastructure changes..."
    cd terraform
    terraform apply
    echo "✅ Infrastructure deployment complete!"

# Complete bootstrap process (plan + apply)
bootstrap:
    #!/usr/bin/env bash
    echo "🚀 Starting complete bootstrap process..."

    # Validate first
    just validate

    # Show plan
    echo "📋 Reviewing planned changes..."
    cd terraform && terraform plan

    # Confirm before applying
    echo ""
    read -p "🤔 Apply these changes? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd terraform && terraform apply -auto-approve
        echo "✅ Bootstrap complete!"
        just status
    else
        echo "❌ Bootstrap cancelled"
    fi

# Destroy all infrastructure (with confirmation)
destroy:
    #!/usr/bin/env bash
    echo "⚠️  WARNING: This will destroy ALL infrastructure!"
    echo "🔍 Current infrastructure status:"
    just status
    echo ""
    read -p "💥 Are you sure you want to destroy everything? (type 'destroy'): " confirm

    if [ "$confirm" = "destroy" ]; then
        echo "🗑️  Destroying infrastructure..."
        cd terraform && terraform destroy
        echo "✅ Infrastructure destroyed"
    else
        echo "❌ Destruction cancelled"
    fi

# Show current infrastructure status
status:
    #!/usr/bin/env bash
    echo "📊 Infrastructure Status:"
    echo "========================"

    cd terraform

    # Check if state exists
    if terraform show -json > /dev/null 2>&1; then
        echo "📦 Terraform State: ✅ Present"

        # Show key outputs
        echo ""
        echo "🔑 Key Outputs:"
        terraform output 2>/dev/null || echo "  (No outputs defined yet)"

        # Show resource count
        echo ""
        echo "📊 Resources:"
        resource_count=$(terraform state list 2>/dev/null | wc -l)
        echo "  Total resources: $resource_count"

    else
        echo "📦 Terraform State: ❌ Not found"
        echo "  Run 'just bootstrap' to create infrastructure"
    fi

# =============================================================================
# Development Workflow
# =============================================================================

# Format Terraform code
format:
    echo "🎨 Formatting Terraform code..."
    cd terraform && terraform fmt -recursive
    echo "✅ Code formatting complete!"

# Lint configuration files
lint:
    #!/usr/bin/env bash
    echo "🔍 Linting configuration files..."

    # Terraform validation
    cd terraform && terraform validate

    # Check for common issues
    if command -v tflint >/dev/null 2>&1; then
        echo "🔍 Running tflint..."
        cd terraform && tflint
    fi

    # Dockerfile linting if hadolint available
    if command -v hadolint >/dev/null 2>&1 && [ -f Dockerfile ]; then
        echo "🔍 Linting Dockerfile..."
        hadolint Dockerfile
    fi

    echo "✅ Linting complete!"

# Run security scanning
security:
    #!/usr/bin/env bash
    echo "🔒 Running security scans..."

    # Terraform security scanning
    if command -v tfsec >/dev/null 2>&1; then
        echo "🔍 Running tfsec..."
        cd terraform && tfsec .
    else
        echo "⚠️  tfsec not found - install for security scanning"
    fi

    # Check for secrets in git
    if command -v truffleHog >/dev/null 2>&1; then
        echo "🔍 Scanning for secrets..."
        truffleHog --regex --entropy=False .
    fi

    echo "✅ Security scanning complete!"

# Generate/update documentation
docs:
    #!/usr/bin/env bash
    echo "📚 Generating documentation..."

    # Generate Terraform docs if available
    if command -v terraform-docs >/dev/null 2>&1; then
        echo "📖 Generating Terraform documentation..."
        cd terraform && terraform-docs markdown table . > README.md
    fi

    # Update architecture diagrams
    echo "🏗️  Updating architecture diagrams..."
    # Add mermaid or plantuml generation here if needed

    echo "✅ Documentation updated!"

# =============================================================================
# Testing and Validation
# =============================================================================

# Run all validation tests
test:
    echo "🧪 Running validation tests..."
    just validate
    just lint
    just security
    echo "✅ All tests passed!"

# Test AWS connectivity and permissions
test-aws:
    #!/usr/bin/env bash
    echo "🔍 Testing AWS connectivity..."

    echo "👤 Current AWS identity:"
    aws sts get-caller-identity

    echo ""
    echo "🔑 Testing IAM permissions..."
    aws iam list-roles --max-items 1 >/dev/null && echo "✅ IAM read access" || echo "❌ IAM access denied"
    aws s3 ls >/dev/null 2>&1 && echo "✅ S3 access" || echo "❌ S3 access denied"

    echo "✅ AWS connectivity test complete!"

# Test Azure DevOps connectivity
test-azdo:
    #!/usr/bin/env bash
    echo "🔍 Testing Azure DevOps connectivity..."

    # Test API access using curl
    response=$(curl -s -u ":$AZDO_PERSONAL_ACCESS_TOKEN" \
        "$AZDO_ORG_SERVICE_URL/_apis/projects?api-version=6.0" \
        -H "Content-Type: application/json")

    if echo "$response" | grep -q '"count"'; then
        echo "✅ Azure DevOps API access successful"
        project_count=$(echo "$response" | grep -o '"count":[0-9]*' | cut -d':' -f2)
        echo "📊 Found $project_count existing projects"
    else
        echo "❌ Azure DevOps API access failed"
        echo "Response: $response"
    fi

# =============================================================================
# Troubleshooting and Debugging
# =============================================================================

# Show detailed logs from last operation
logs:
    #!/usr/bin/env bash
    echo "📋 Recent Terraform logs:"
    if [ -f terraform-debug.log ]; then
        tail -50 terraform-debug.log
    else
        echo "No debug logs found. Set TF_LOG=DEBUG to enable logging."
    fi

# Reset Terraform state (use with caution)
reset:
    #!/usr/bin/env bash
    echo "⚠️  Resetting Terraform state..."
    echo "This will:"
    echo "  - Remove local state lock"
    echo "  - Reinitialize Terraform"
    echo "  - May cause state inconsistencies"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd terraform
        rm -f .terraform.lock.hcl
        rm -rf .terraform
        terraform init
        echo "✅ Terraform reset complete"
    else
        echo "❌ Reset cancelled"
    fi

# Clean up temporary files
clean:
    echo "🧹 Cleaning up temporary files..."
    rm -f terraform-debug.log
    rm -f .terraform.lock.hcl.backup
    find . -name "*.tfplan" -delete
    find . -name ".terraform.tmp*" -delete
    echo "✅ Cleanup complete!"

# Show debug information
debug:
    #!/usr/bin/env bash
    echo "🐛 Debug Information:"
    echo "===================="
    echo "Environment: $(basename $PWD)"
    echo "Git branch: $(git branch --show-current 2>/dev/null || echo 'not a git repo')"
    echo "Git status: $(git status --porcelain 2>/dev/null | wc -l) changed files"
    echo ""
    echo "🔧 Tool Versions:"
    terraform version
    aws --version
    echo ""
    echo "📊 AWS Account: $(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'not authenticated')"
    echo "🌍 AWS Region: $AWS_DEFAULT_REGION"
    echo ""
    echo "🏗️  Terraform Workspace: $(cd terraform && terraform workspace show 2>/dev/null || echo 'not initialized')"

# =============================================================================
# Help and Information
# =============================================================================

# Show help for common workflows
help:
    #!/usr/bin/env bash
    cat << 'EOF'

📚 Azure DevOps + AWS Foundation Help
====================================

🚀 Quick Start:
  just setup      # Initialize development environment
  just validate   # Check configuration and dependencies
  just bootstrap  # Create complete infrastructure

📋 Daily Workflow:
  just plan       # Review changes before applying
  just apply      # Apply infrastructure changes
  just status     # Check current infrastructure state

🔧 Development:
  just format     # Format Terraform code
  just lint       # Lint configuration files
  just test       # Run all validation tests

🐛 Troubleshooting:
  just debug      # Show debug information
  just logs       # View recent operation logs
  just reset      # Reset Terraform state (caution!)

📚 Documentation:
  See README.md for complete setup instructions
  See docs/ directory for detailed documentation

❓ Need help? Check docs/troubleshooting.md

EOF

# Show project information
info:
    #!/usr/bin/env bash
    echo "📋 Project Information:"
    echo "======================"
    echo "Name: Azure DevOps + AWS Foundation"
    echo "Purpose: Enterprise CI/CD demonstration"
    echo "Repository: $(git remote get-url origin 2>/dev/null || echo 'local development')"
    echo ""
    echo "📊 Project Status:"
    if [ -d terraform ] && [ -d docs ]; then
        echo "  Structure: ✅ Complete"
    else
        echo "  Structure: ⚠️  Incomplete"
    fi

    if [ -f .env.local ]; then
        echo "  Configuration: ✅ Present"
    else
        echo "  Configuration: ❌ Missing .env.local"
    fi