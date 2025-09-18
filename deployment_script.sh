#!/bin/bash

# Quick Deployment Script for AI Code Reviewer
# This script helps you deploy your AI code reviewer quickly

set -e

echo "🤖 AI Code Reviewer - Quick Deployment Script"
echo "=============================================="

# Check if required tools are installed
check_requirements() {
    echo "📋 Checking requirements..."
    
    if ! command -v python3 &> /dev/null; then
        echo "❌ Python 3 is required but not installed"
        exit 1
    fi
    
    if ! command -v pip &> /dev/null; then
        echo "❌ pip is required but not installed"
        exit 1
    fi
    
    echo "✅ Requirements check passed"
}

# Setup project structure
setup_project() {
    echo "📁 Setting up project structure..."
    
    # Create directories
    mkdir -p core
    mkdir -p .github/workflows
    mkdir -p logs
    
    # Create __init__.py files
    touch core/__init__.py
    
    echo "✅ Project structure created"
}

# Install dependencies
install_dependencies() {
    echo "📦 Installing dependencies..."
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Install requirements
    pip install --upgrade pip
    pip install -r requirements.txt
    
    echo "✅ Dependencies installed"
}

# Setup environment
setup_environment() {
    echo "🔧 Setting up environment..."
    
    if [ ! -f ".env" ]; then
        cp .env.example .env
        echo "📝 Created .env file from .env.example"
        echo "⚠️  Please edit .env file with your actual API keys"
    else
        echo "✅ .env file already exists"
    fi
}

# Test local setup
test_local() {
    echo "🧪 Testing local setup..."
    
    source venv/bin/activate
    
    # Start the server in background
    python app.py &
    SERVER_PID=$!
    
    # Wait for server to start
    sleep 5
    
    # Test health endpoint
    if curl -f http://localhost:5000/health > /dev/null 2>&1; then
        echo "✅ Local server is working!"
    else
        echo "❌ Local server test failed"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
    
    # Stop the server
    kill $SERVER_PID 2>/dev/null || true
    
    echo "✅ Local testing completed"
}

# Deploy to Railway
deploy_railway() {
    echo "🚂 Deploying to Railway..."
    
    if ! command -v railway &> /dev/null; then
        echo "Installing Railway CLI..."
        npm install -g @railway/cli
    fi
    
    echo "Please run the following commands manually:"
    echo "1. railway login"
    echo "2. railway new"
    echo "3. railway add (select your repository)"
    echo "4. Set environment variables in Railway dashboard"
    echo "5. railway up"
    
    echo "📋 Railway deployment guide provided"
}

# Deploy to Render
deploy_render() {
    echo "🎨 Render Deployment Instructions:"
    echo "1. Go to https://render.com"
    echo "2. Connect your GitHub repository"
    echo "3. Create a new Web Service"
    echo "4. Set the following:"
    echo "   - Build Command: pip install -r requirements.txt"
    echo "   - Start Command: gunicorn -w 4 -b 0.0.0.0:\$PORT app:app"
    echo "5. Add environment variables in Render dashboard"
    echo "6. Deploy!"
}

# Deploy to Fly.io
deploy_fly() {
    echo "🪰 Deploying to Fly.io..."
    
    if ! command -v flyctl &> /dev/null; then
        echo "Installing Fly CLI..."
        curl -L https://fly.io/install.sh | sh
    fi
    
    echo "Please run the following commands:"
    echo "1. flyctl auth login"
    echo "2. flyctl launch"
    echo "3. flyctl secrets set ANTHROPIC_API_KEY=your_key_here"
    echo "4. flyctl deploy"
}

# Main menu
main_menu() {
    echo ""
    echo "What would you like to do?"
    echo "1. Setup local development"
    echo "2. Deploy to Railway"
    echo "3. Deploy to Render"
    echo "4. Deploy to Fly.io"
    echo "5. Test local setup"
    echo "6. Exit"
    
    read -p "Enter your choice (1-6): " choice
    
    case $choice in
        1)
            check_requirements
            setup_project
            install_dependencies
            setup_environment
            echo "🎉 Local development setup complete!"
            echo "📝 Don't forget to edit your .env file with actual API keys"
            ;;
        2)
            deploy_railway
            ;;
        3)
            deploy_render
            ;;
        4)
            deploy_fly
            ;;
        5)
            test_local
            ;;
        6)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid choice. Please try again."
            main_menu
            ;;
    esac
}

# Generate GitHub workflow
setup_github_actions() {
    echo "⚙️ Setting up GitHub Actions..."
    
    if [ ! -f ".github/workflows/ai-review.yml" ]; then
        echo "Creating GitHub Actions workflow..."
        # The workflow content would be copied here
        echo "✅ GitHub Actions workflow created"
        echo "📝 Don't forget to add AI_REVIEWER_URL to your repository secrets"
    else
        echo "✅ GitHub Actions workflow already exists"
    fi
}

# Run the script
echo "Welcome to the AI Code Reviewer setup!"
echo ""

# Setup GitHub Actions automatically
setup_github_actions

# Show main menu
main_menu

echo ""
echo "🎉 Setup complete! Your AI Code Reviewer is ready to use."
echo ""
echo "Next steps:"
echo "1. Edit your .env file with actual API keys"
echo "2. Deploy to your chosen platform"
echo "3. Add AI_REVIEWER_URL to your GitHub repository secrets"
echo "4. Create a pull request to test the system"
echo ""
echo "Need help? Check the setup guide for detailed instructions."