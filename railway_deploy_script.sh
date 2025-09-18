#!/bin/bash

# Railway Build Fix Script
# This script fixes the Railway deployment issue

set -e

echo "🔧 Fixing Railway Build Configuration..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Create Procfile for Railway
create_procfile() {
    print_info "Creating Procfile..."

    cat > Procfile << 'EOF'
web: gunicorn --bind 0.0.0.0:$PORT --workers 2 --timeout 120 app:app
EOF

    print_status "Procfile created"
}

# Create start.sh script
create_start_script() {
    print_info "Creating start.sh script..."

    cat > start.sh << 'EOF'
#!/bin/bash

# Start script for Railway deployment
echo "🚀 Starting AI Code Reviewer..."

# Set default port if not provided
export PORT=${PORT:-5000}

# Start the application with gunicorn
exec gunicorn --bind 0.0.0.0:$PORT --workers 2 --timeout 120 app:app
EOF

    chmod +x start.sh
    print_status "start.sh script created and made executable"
}

# Update Dockerfile with proper CMD
update_dockerfile() {
    print_info "Updating Dockerfile..."

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
EXPOSE $PORT

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:$PORT/health || exit 1

# Run the application
CMD ["./start.sh"]
EOF

    print_status "Dockerfile updated"
}

# Update railway.json with correct build settings
update_railway_json() {
    print_info "Updating railway.json..."

    cat > railway.json << 'EOF'
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "numReplicas": 1,
    "sleepApplication": false,
    "restartPolicyType": "ON_FAILURE"
  }
}
EOF

    print_status "railway.json updated"
}

# Create nixpacks.toml for better build detection
create_nixpacks_config() {
    print_info "Creating nixpacks.toml..."

    cat > nixpacks.toml << 'EOF'
[phases.setup]
nixPkgs = ["python311", "pip"]

[phases.install]
cmds = ["pip install -r requirements.txt"]

[phases.build]
cmds = ["echo 'Build phase complete'"]

[start]
cmd = "gunicorn --bind 0.0.0.0:$PORT --workers 2 --timeout 120 app:app"
EOF

    print_status "nixpacks.toml created"
}

# Ensure all required files exist
check_required_files() {
    print_info "Checking required files..."

    # Check if app.py exists
    if [ ! -f "app.py" ]; then
        print_error "app.py not found! Make sure you have the Flask application file."
        exit 1
    fi

    # Check if requirements.txt exists
    if [ ! -f "requirements.txt" ]; then
        print_warning "requirements.txt not found. Creating it..."
        cat > requirements.txt << 'EOF'
Flask==3.0.0
anthropic==0.25.0
gunicorn==21.2.0
requests==2.31.0
python-dotenv==1.0.0
EOF
        print_status "requirements.txt created"
    fi

    # Check if core/models.py exists
    if [ ! -f "core/models.py" ]; then
        print_warning "core/models.py not found. Creating it..."
        mkdir -p core
        cat > core/models.py << 'EOF'
from dataclasses import dataclass
from typing import List, Dict, Any, Optional
from datetime import datetime

@dataclass
class ReviewResult:
    security_score: int
    quality_score: int
    vulnerabilities: List[Dict[str, Any]]
    issues: List[Dict[str, Any]]
    summary: str
    recommendations: List[str]
    approval: str
    ai_confidence: float
    timestamp: Optional[datetime] = None

    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.utcnow()
EOF

        cat > core/__init__.py << 'EOF'
from .models import ReviewResult
__all__ = ['ReviewResult']
EOF
        print_status "core/models.py created"
    fi

    print_status "Required files check completed"
}

# Update .gitignore
update_gitignore() {
    if [ ! -f ".gitignore" ]; then
        print_info "Creating .gitignore..."
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

# Railway
.railway/
EOF
        print_status ".gitignore created"
    fi
}

# Commit changes to git
commit_changes() {
    print_info "Committing changes to git..."

    git add .
    if git diff --staged --quiet; then
        print_info "No changes to commit"
    else
        git commit -m "Fix Railway deployment configuration"
        print_status "Changes committed"
    fi
}

# Deploy to Railway
deploy_railway() {
    print_info "Deploying to Railway..."

    if railway up --detach; then
        print_status "Deployment started successfully!"

        print_info "Waiting for deployment to complete..."
        sleep 30

        # Try to get the URL
        RAILWAY_URL=$(railway domain 2>/dev/null || echo "")

        if [ -n "$RAILWAY_URL" ]; then
            print_status "Application deployed at: https://$RAILWAY_URL"

            # Test the deployment
            print_info "Testing deployment..."
            if curl -f "https://$RAILWAY_URL/health" > /dev/null 2>&1; then
                print_status "✅ Deployment successful! Health check passed."
            else
                print_warning "Deployment completed but health check failed. Service might still be starting."
            fi
        else
            print_info "Deployment in progress. Check Railway dashboard for URL."
        fi
    else
        print_error "Deployment failed. Check the logs below:"
        railway logs
    fi
}

# Show Railway logs
show_logs() {
    print_info "Recent deployment logs:"
    railway logs --tail 20
}

# Main execution
main() {
    echo ""
    print_info "Fixing Railway deployment configuration..."
    echo ""

    check_required_files
    create_procfile
    create_start_script
    update_dockerfile
    update_railway_json
    create_nixpacks_config
    update_gitignore
    commit_changes

    echo ""
    print_status "Configuration fixed! Ready to deploy."
    echo ""

    read -p "Deploy to Railway now? (y/n): " deploy_choice

    if [[ $deploy_choice =~ ^[Yy]$ ]]; then
        deploy_railway
    else
        print_info "You can deploy later with: railway up"
    fi

    echo ""
    print_status "All done! Your Railway configuration is fixed."
    echo ""

    print_info "If deployment fails, try:"
    echo "1. railway logs (to see error details)"
    echo "2. Check Railway dashboard for build logs"
    echo "3. Ensure environment variables are set in Railway dashboard"
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi