# Azure DevOps + AWS Foundation Automation
# Requires: just, direnv, terraform, aws cli

# Load environment variables from .env.local
set dotenv-load

# Default recipe - show available commands
default:
    @just --list

# Validate environment configuration and tool dependencies
validate:
    #!/usr/bin/env bash
    echo "Validating environment and dependencies..."

    # Check required tools
    command -v terraform >/dev/null 2>&1 || { echo "ERROR: terraform not found"; exit 1; }
    command -v aws >/dev/null 2>&1 || { echo "ERROR: aws cli not found"; exit 1; }
    command -v direnv >/dev/null 2>&1 || { echo "ERROR: direnv not found"; exit 1; }

    # Check environment file exists
    if [ ! -f .env.local ]; then
        echo "ERROR: .env.local not found. Copy from .env.local.example and configure."
        exit 1
    fi

    # Test AWS connectivity
    echo "Testing AWS connectivity..."
    aws sts get-caller-identity --query 'Account' --output text --no-cli-pager || { echo "ERROR: AWS authentication failed"; exit 1; }

    # Validate Terraform configuration
    echo "Validating Terraform configuration..."
    cd terraform && terraform validate

    echo "SUCCESS: Environment validation complete!"

# Initialize development environment
setup:
    #!/usr/bin/env bash
    echo "Setting up development environment..."

    # Ensure .env.local exists
    if [ ! -f .env.local ]; then
        cp .env.local.example .env.local
        echo "Created .env.local from template - please configure it!"
        exit 1
    fi

    # Setup Terraform Cloud credentials if token is provided
    if [ -n "$TERRAFORM_CLOUD_TOKEN" ]; then
        echo "Setting up Terraform Cloud credentials..."
        mkdir -p ~/.terraform.d
        echo "{" > ~/.terraform.d/credentials.tfrc.json
        echo "  \"credentials\": {" >> ~/.terraform.d/credentials.tfrc.json
        echo "    \"app.terraform.io\": {" >> ~/.terraform.d/credentials.tfrc.json
        echo "      \"token\": \"$TERRAFORM_CLOUD_TOKEN\"" >> ~/.terraform.d/credentials.tfrc.json
        echo "    }" >> ~/.terraform.d/credentials.tfrc.json
        echo "  }" >> ~/.terraform.d/credentials.tfrc.json
        echo "}" >> ~/.terraform.d/credentials.tfrc.json
        echo "Terraform Cloud credentials configured"
    else
        echo "No TERRAFORM_CLOUD_TOKEN found - you may need to run 'terraform login'"
    fi

    # Initialize Terraform
    echo "Initializing Terraform..."
    cd terraform && terraform init

    echo "SUCCESS: Development environment ready!"

# Show planned infrastructure changes
plan:
    #!/usr/bin/env bash
    echo "Planning infrastructure changes..."
    cd terraform
    terraform plan -detailed-exitcode

    if [ $? -eq 2 ]; then
        echo "Changes detected - review plan above"
    else
        echo "No changes needed"
    fi

# Apply infrastructure changes (interactive)
apply:
    #!/usr/bin/env bash
    echo "Applying infrastructure changes..."
    cd terraform
    terraform apply
    echo "Infrastructure deployment complete!"

# Complete bootstrap process (plan + apply)
bootstrap:
    #!/usr/bin/env bash
    echo "Starting complete bootstrap process..."

    # Validate first
    just validate

    # Show plan
    echo "Reviewing planned changes..."
    cd terraform && terraform plan

    # Confirm before applying
    echo ""
    read -p "Apply these changes? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        just apply
        echo "Bootstrap complete!"
        just status
    else
        echo "Bootstrap cancelled"
    fi

# Destroy all infrastructure (with confirmation)
destroy:
    #!/usr/bin/env bash
    echo "WARNING: This will destroy ALL infrastructure!"
    echo "Current infrastructure status:"
    just status
    echo ""
    read -p "Are you sure you want to destroy everything? (type 'destroy'): " confirm

    if [ "$confirm" = "destroy" ]; then
        echo "Destroying infrastructure..."
        cd terraform && terraform destroy
        echo "Infrastructure destroyed"
    else
        echo "Destruction cancelled"
    fi

# Show current infrastructure status
status:
    #!/usr/bin/env bash
    echo "Infrastructure Status:"
    echo "======================"

    cd terraform

    # Check if state exists
    if terraform show -json > /dev/null 2>&1; then
        echo "Terraform State: Present"

        # Show key outputs
        echo ""
        echo "Key Outputs:"
        terraform output 2>/dev/null || echo "  (No outputs defined yet)"

        # Show resource count
        echo ""
        echo "Resources:"
        resource_count=$(terraform state list 2>/dev/null | wc -l)
        echo "  Total resources: $resource_count"

    else
        echo "Terraform State: Not found"
        echo "  Run 'just bootstrap' to create infrastructure"
    fi

# Format Terraform code
format:
    echo "Formatting Terraform code..."
    cd terraform && terraform fmt -recursive
    echo "Code formatting complete!"

# Lint configuration files
lint:
    #!/usr/bin/env bash
    echo "Linting configuration files..."

    # Terraform validation
    cd terraform && terraform validate

    # Check for common issues
    if command -v tflint >/dev/null 2>&1; then
        echo "Running tflint..."
        cd terraform && tflint
    fi

    echo "Linting complete!"

# Run all validation tests
test:
    echo "Running validation tests..."
    just validate
    just lint
    echo "All tests passed!"

# Test AWS connectivity and permissions
test-aws:
    #!/usr/bin/env bash
    echo "Testing AWS connectivity..."

    echo "Current AWS identity:"
    aws sts get-caller-identity

    echo ""
    echo "Testing IAM permissions..."
    aws iam list-roles --max-items 1 >/dev/null && echo "IAM read access: OK" || echo "IAM access: DENIED"
    aws s3 ls >/dev/null 2>&1 && echo "S3 access: OK" || echo "S3 access: DENIED"

    echo "AWS connectivity test complete!"

# Test Azure DevOps connectivity
test-azdo:
    #!/usr/bin/env bash
    echo "Testing Azure DevOps connectivity..."

    # Test API access using curl
    response=$(curl -s -u ":$AZDO_PERSONAL_ACCESS_TOKEN" \
        "$AZDO_ORG_SERVICE_URL/_apis/projects?api-version=6.0" \
        -H "Content-Type: application/json")

    if echo "$response" | grep -q '"count"'; then
        echo "Azure DevOps API access: OK"
        project_count=$(echo "$response" | grep -o '"count":[0-9]*' | cut -d':' -f2)
        echo "Found $project_count existing projects"
    else
        echo "Azure DevOps API access: FAILED"
        echo "Response: $response"
    fi

# Show debug information
debug:
    #!/usr/bin/env bash
    echo "Debug Information:"
    echo "=================="
    echo "Environment: $(basename $PWD)"
    echo "Git branch: $(git branch --show-current 2>/dev/null || echo 'not a git repo')"
    echo ""
    echo "Tool Versions:"
    terraform version
    aws --version
    echo ""
    echo "AWS Account: $(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'not authenticated')"
    echo "AWS Region: $AWS_DEFAULT_REGION"

# Clean up temporary files
clean:
    echo "Cleaning up temporary files..."
    rm -f terraform-debug.log
    rm -f .terraform.lock.hcl.backup
    find . -name "*.tfplan" -delete
    find . -name ".terraform.tmp*" -delete
    echo "Cleanup complete!"

# Show help for common workflows
help:
    @echo ""
    @echo "Azure DevOps + AWS Foundation Help"
    @echo "=================================="
    @echo ""
    @echo "Quick Start:"
    @echo "  just setup      # Initialize development environment"
    @echo "  just validate   # Check configuration and dependencies"
    @echo "  just bootstrap  # Create complete infrastructure"
    @echo ""
    @echo "Daily Workflow:"
    @echo "  just plan       # Review changes before applying"
    @echo "  just apply      # Apply infrastructure changes"
    @echo "  just status     # Check current infrastructure state"
    @echo ""
    @echo "Development:"
    @echo "  just format     # Format Terraform code"
    @echo "  just lint       # Lint configuration files"
    @echo "  just test       # Run all validation tests"
    @echo ""
    @echo "Troubleshooting:"
    @echo "  just debug      # Show debug information"
    @echo "  just clean      # Clean up temporary files"
    @echo ""