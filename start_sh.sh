#!/bin/bash

# Install dependencies if not already installed
pip install --no-cache-dir -r requirements.txt

# Check if gunicorn is available, if not use Flask directly
if command -v gunicorn &> /dev/null; then
    echo "Starting with gunicorn..."
    exec gunicorn --bind 0.0.0.0:${PORT:-8001} --workers 1 --timeout 120 app:app
else
    echo "Gunicorn not found, starting with Flask development server..."
    exec python app.py
fi