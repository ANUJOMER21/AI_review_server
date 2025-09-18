#!/bin/bash

# Railway Deployment Script for AI Code Reviewer
# This script sets up and deploys your AI code reviewer to Railway

set -e

echo "🚂 AI Code Reviewer - Railway Deployment Script"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if required tools are installed
check_requirements() {
    print_info "Checking requirements..."
    
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not installed"
        exit 1
    fi
    
    if ! command -v pip &> /dev/null; then
        print_error "pip is required but not installed"
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        print_error "Git is required but not installed"
        exit 1
    fi
    
    if ! command -v node &> /dev/null; then
        print_warning "Node.js not found. Installing Railway CLI will require Node.js"
    fi
    
    print_status "Requirements check passed"
}

# Setup project structure
setup_project() {
    print_info "Setting up project structure..."
    
    # Create directories
    mkdir -p core
    mkdir -p .github/workflows
    mkdir -p logs
    
    # Create __init__.py files
    cat > core/__init__.py << 'EOF'
"""Core models and utilities for AI Code Reviewer"""

from .models import ReviewResult, Vulnerability, CodeIssue, ComplexityAnalysis

__all__ = ['ReviewResult', 'Vulnerability', 'CodeIssue', 'ComplexityAnalysis']
EOF
    
    # Create requirements.txt
    cat > requirements.txt << 'EOF'
Flask==3.0.0
anthropic==0.25.0
gunicorn==21.2.0
requests==2.31.0
python-dotenv==1.0.0
EOF
    
    # Create Dockerfile
    cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Run the application
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "120", "app:app"]
EOF
    
    # Create .env.example
    cat > .env.example << 'EOF'
ANTHROPIC_API_KEY=your_anthropic_api_key_here
GITHUB_WEBHOOK_SECRET=your_github_webhook_secret_here
ALLOWED_REPOS=owner/repo1,owner/repo2
FLASK_DEBUG=false
PORT=5000
EOF

    # Create .gitignore
    cat > .gitignore << 'EOF'
# Environment variables
.env

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Virtual environments
venv/
env/
ENV/

# IDE
.vscode/
.idea/
*.swp
*.swo

# Logs
logs/
*.log

# OS
.DS_Store
Thumbs.db
EOF

    # Create railway.json
    cat > railway.json << 'EOF'
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "DOCKERFILE"
  },
  "deploy": {
    "numReplicas": 1,
    "sleepApplication": false,
    "restartPolicyType": "ON_FAILURE"
  }
}
EOF
    
    print_status "Project structure created"
}

# Install Railway CLI
install_railway_cli() {
    print_info "Installing Railway CLI..."
    
    if command -v railway &> /dev/null; then
        print_status "Railway CLI is already installed"
        return
    fi
    
    if command -v npm &> /dev/null; then
        npm install -g @railway/cli
        print_status "Railway CLI installed via npm"
    elif command -v yarn &> /dev/null; then
        yarn global add @railway/cli
        print_status "Railway CLI installed via yarn"
    else
        print_warning "Node.js/npm not found. Installing Railway CLI manually..."
        
        # Detect OS and install accordingly
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            curl -fsSL https://railway.app/install.sh | sh
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            curl -fsSL https://railway.app/install.sh | sh
        else
            print_error "Unsupported OS. Please install Railway CLI manually from https://docs.railway.app/develop/cli"
            exit 1
        fi
        
        print_status "Railway CLI installed"
    fi
}

# Setup environment
setup_environment() {
    print_info "Setting up environment..."
    
    if [ ! -f ".env" ]; then
        cp .env.example .env
        print_status "Created .env file from .env.example"
        print_warning "Please edit .env file with your actual API keys before deployment"
    else
        print_status ".env file already exists"
    fi
}

# Get API keys from user
collect_api_keys() {
    print_info "Collecting API configuration..."
    
    echo ""
    echo "📋 Please provide your API configuration:"
    echo ""
    
    # Get Anthropic API key
    if [ -z "$ANTHROPIC_API_KEY" ]; then
        read -p "🔑 Enter your Anthropic API key: " ANTHROPIC_API_KEY
        if [ -z "$ANTHROPIC_API_KEY" ]; then
            print_error "Anthropic API key is required!"
            exit 1
        fi
    fi
    
    # Get GitHub webhook secret (optional)
    if [ -z "$GITHUB_WEBHOOK_SECRET" ]; then
        read -p "🔐 Enter GitHub webhook secret (press Enter to generate): " GITHUB_WEBHOOK_SECRET
        if [ -z "$GITHUB_WEBHOOK_SECRET" ]; then
            GITHUB_WEBHOOK_SECRET=$(openssl rand -hex 20 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(20))")
            print_info "Generated webhook secret: $GITHUB_WEBHOOK_SECRET"
        fi
    fi
    
    # Get allowed repositories (optional)
    if [ -z "$ALLOWED_REPOS" ]; then
        read -p "📁 Enter allowed repositories (comma-separated, or press Enter for all): " ALLOWED_REPOS
    fi
    
    # Update .env file
    cat > .env << EOF
ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY
GITHUB_WEBHOOK_SECRET=$GITHUB_WEBHOOK_SECRET
ALLOWED_REPOS=$ALLOWED_REPOS
FLASK_DEBUG=false
PORT=5000
EOF
    
    print_status "API configuration saved to .env"
}

# Initialize git repository if needed
init_git() {
    if [ ! -d ".git" ]; then
        print_info "Initializing git repository..."
        git init
        git add .
        git commit -m "Initial commit: AI Code Reviewer setup"
        print_status "Git repository initialized"
    else
        print_status "Git repository already exists"
        
        # Add new files
        git add .
        if git diff --staged --quiet; then
            print_info "No changes to commit"
        else
            git commit -m "Update AI Code Reviewer configuration"
            print_status "Changes committed"
        fi
    fi
}

# Deploy to Railway
deploy_to_railway() {
    print_info "Deploying to Railway..."
    
    echo ""
    print_info "Railway deployment process:"
    echo "1. Login to Railway"
    echo "2. Create new project"
    echo "3. Deploy application"
    echo "4. Set environment variables"
    echo ""
    
    # Login to Railway
    print_info "Step 1: Logging into Railway..."
    if ! railway login; then
        print_error "Railway login failed"
        exit 1
    fi
    
    print_status "Successfully logged into Railway"
    
    # Create new project or link existing
    print_info "Step 2: Setting up Railway project..."
    
    echo ""
    echo "Choose an option:"
    echo "1. Create new Railway project"
    echo "2. Link to existing Railway project"
    read -p "Enter your choice (1-2): " project_choice
    
    case $project_choice in
        1)
            print_info "Creating new Railway project..."
            if railway new; then
                print_status "New Railway project created"
            else
                print_error "Failed to create Railway project"
                exit 1
            fi
            ;;
        2)
            print_info "Linking to existing Railway project..."
            railway link
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    # Set environment variables
    print_info "Step 3: Setting environment variables..."
    
    railway variables set ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
    railway variables set GITHUB_WEBHOOK_SECRET="$GITHUB_WEBHOOK_SECRET"
    
    if [ -n "$ALLOWED_REPOS" ]; then
        railway variables set ALLOWED_REPOS="$ALLOWED_REPOS"
    fi
    
    railway variables set FLASK_DEBUG="false"
    
    print_status "Environment variables set"
    
    # Deploy the application
    print_info "Step 4: Deploying application..."
    
    if railway up; then
        print_status "Application deployed successfully!"
    else
        print_error "Deployment failed"
        exit 1
    fi
    
    # Get the deployment URL
    print_info "Getting deployment URL..."
    RAILWAY_URL=$(railway domain 2>/dev/null || echo "")
    
    if [ -n "$RAILWAY_URL" ]; then
        print_status "Application deployed at: https://$RAILWAY_URL"
        echo ""
        print_info "Your AI Reviewer API endpoints:"
        echo "  Health Check: https://$RAILWAY_URL/health"
        echo "  Manual Review: https://$RAILWAY_URL/review"
        echo "  GitHub Webhook: https://$RAILWAY_URL/webhook/github"
        echo ""
        echo "🔗 Add this to your GitHub repository secrets:"
        echo "  AI_REVIEWER_URL=https://$RAILWAY_URL"
    else
        print_warning "Could not retrieve deployment URL. Check Railway dashboard."
    fi
}

# Create GitHub Actions workflow
setup_github_actions() {
    print_info "Setting up GitHub Actions workflow..."
    
    mkdir -p .github/workflows
    
    cat > .github/workflows/ai-review.yml << 'EOF'
name: AI Code Review

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  ai-review:
    runs-on: ubuntu-latest
    
    permissions:
      contents: read
      pull-requests: write
      actions: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get PR files
        id: get-files
        uses: actions/github-script@v7
        with:
          script: |
            const { data: files } = await github.rest.pulls.listFiles({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.issue.number,
            });
            
            const processedFiles = files.map(file => ({
              filename: file.filename,
              status: file.status,
              additions: file.additions,
              deletions: file.deletions,
              changes: file.changes,
              patch: file.patch || '',
              file_type: file.filename.split('.').pop() || 'unknown',
              is_binary: file.filename.match(/\.(jpg|jpeg|png|gif|ico|svg|pdf|zip|tar|gz|exe|dll|so|dylib)$/i) ? true : false,
              size: file.patch ? file.patch.length : 0
            }));
            
            return processedFiles;

      - name: Call AI Review API
        id: ai-review
        run: |
          cat > payload.json << 'EOF'
          {
            "pr_title": "${{ github.event.pull_request.title }}",
            "pr_body": "${{ github.event.pull_request.body }}",
            "pr_number": ${{ github.event.pull_request.number }},
            "pr_url": "${{ github.event.pull_request.html_url }}",
            "files": ${{ steps.get-files.outputs.result }},
            "preferences": {
              "focus_security": true,
              "focus_performance": false,
              "strict_style": false
            }
          }
          EOF
          
          response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -d @payload.json \
            ${{ secrets.AI_REVIEWER_URL }}/review)
          
          echo "response=$response" >> $GITHUB_OUTPUT
          
          markdown_report=$(echo "$response" | jq -r '.markdown_report // empty')
          if [ -n "$markdown_report" ]; then
            echo "markdown_report<<EOF" >> $GITHUB_OUTPUT
            echo "$markdown_report" >> $GITHUB_OUTPUT
            echo "EOF" >> $GITHUB_OUTPUT
          fi
          
          approval=$(echo "$response" | jq -r '.review.approval // "COMMENT"')
          echo "approval=$approval" >> $GITHUB_OUTPUT
          
          security_score=$(echo "$response" | jq -r '.review.security_score // 0')
          quality_score=$(echo "$response" | jq -r '.review.quality_score // 0')
          echo "security_score=$security_score" >> $GITHUB_OUTPUT
          echo "quality_score=$quality_score" >> $GITHUB_OUTPUT

      - name: Create review comment
        if: steps.ai-review.outputs.markdown_report != ''
        uses: actions/github-script@v7
        with:
          script: |
            const markdownReport = `${{ steps.ai-review.outputs.markdown_report }}`;
            
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: markdownReport
            });

      - name: Set PR status check
        uses: actions/github-script@v7
        with:
          script: |
            const approval = '${{ steps.ai-review.outputs.approval }}';
            const securityScore = parseInt('${{ steps.ai-review.outputs.security_score }}');
            const qualityScore = parseInt('${{ steps.ai-review.outputs.quality_score }}');
            
            let state = 'success';
            let description = 'AI review completed successfully';
            
            if (approval === 'REQUEST_CHANGES') {
              state = 'failure';
              description = 'AI review found issues that need attention';
            } else if (securityScore < 70 || qualityScore < 70) {
              state = 'pending';
              description = 'AI review suggests improvements';
            }
            
            await github.rest.repos.createCommitStatus({
              owner: context.repo.owner,
              repo: context.repo.repo,
              sha: context.payload.pull_request.head.sha,
              state: state,
              description: description,
              context: 'AI Code Review',
              target_url: '${{ github.event.pull_request.html_url }}'
            });

      - name: Save review report as artifact
        if: steps.ai-review.outputs.markdown_report != ''
        run: |
          mkdir -p ai-reviews
          echo '${{ steps.ai-review.outputs.markdown_report }}' > "ai-reviews/pr-${{ github.event.pull_request.number }}-review.md"

      - name: Upload review artifact
        if: steps.ai-review.outputs.markdown_report != ''
        uses: actions/upload-artifact@v4
        with:
          name: ai-review-pr-${{ github.event.pull_request.number }}
          path: ai-reviews/
          retention-days: 30

      - name: Handle API errors
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: `## ❌ AI Code Review Failed
              
              The automated AI code review could not be completed. This may be due to:
              - Service unavailability
              - API rate limits
              - Network issues
              
              Please review this PR manually or try triggering the review again.
              
              *Generated at: ${new Date().toISOString()}*`
            });
EOF
    
    print_status "GitHub Actions workflow created"
}

# Test the deployment
test_deployment() {
    if [ -n "$RAILWAY_URL" ]; then
        print_info "Testing deployment..."
        
        sleep 10  # Wait for deployment to be ready
        
        if curl -f "https://$RAILWAY_URL/health" > /dev/null 2>&1; then
            print_status "Deployment test passed!"
        else
            print_warning "Deployment test failed. The service might still be starting up."
            print_info "You can check the status at: https://$RAILWAY_URL/health"
        fi
    fi
}

# Display final instructions
show_final_instructions() {
    echo ""
    echo "🎉 Railway deployment completed successfully!"
    echo ""
    print_info "Next steps:"
    echo ""
    echo "1. 🔗 Add the following secret to your GitHub repository:"
    echo "   Go to: Settings > Secrets and variables > Actions"
    if [ -n "$RAILWAY_URL" ]; then
        echo "   Secret name: AI_REVIEWER_URL"
        echo "   Secret value: https://$RAILWAY_URL"
    else
        echo "   Secret name: AI_REVIEWER_URL"
        echo "   Secret value: [Your Railway URL from dashboard]"
    fi
    echo ""
    echo "2. 🧪 Test your setup:"
    echo "   - Create a pull request in your repository"
    echo "   - Check if the AI review comment appears"
    echo "   - Verify the status check is set"
    echo ""
    echo "3. 📊 Monitor your application:"
    echo "   - Railway Dashboard: https://railway.app/dashboard"
    if [ -n "$RAILWAY_URL" ]; then
        echo "   - Health Check: https://$RAILWAY_URL/health"
        echo "   - API Endpoint: https://$RAILWAY_URL/review"
    fi
    echo ""
    echo "4. 🔧 Troubleshooting:"
    echo "   - Check Railway logs if there are issues"
    echo "   - Verify your Anthropic API key has sufficient credits"
    echo "   - Ensure GitHub Actions workflow is enabled"
    echo ""
    print_status "Your AI Code Reviewer is now live on Railway! 🚂"
}

# Main execution
main() {
    echo ""
    
    # Run setup steps
    check_requirements
    setup_project
    install_railway_cli
    setup_environment
    collect_api_keys
    init_git
    setup_github_actions
    deploy_to_railway
    test_deployment
    show_final_instructions
    
    echo ""
    print_status "All done! Your AI Code Reviewer is ready to analyze pull requests."
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi