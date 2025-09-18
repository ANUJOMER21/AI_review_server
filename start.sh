#!/bin/bash

# Start script for Railway deployment
echo "🚀 Starting AI Code Reviewer..."

# Set default port if not provided
export PORT=${PORT:-5000}

# Start the application with gunicorn
exec gunicorn --bind 0.0.0.0:$PORT --workers 2 --timeout 120 app:app
