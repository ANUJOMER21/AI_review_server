#!/bin/bash

# Install dependencies if not already installed
pip install --no-cache-dir -r requirements.txt

# Check if gunicorn is available, if not use Flask directly

echo "Gunicorn not found, starting with Flask development server..."

exec python app.py
fi