FROM python:3.11-slim

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# Verify gunicorn installation
RUN python -c "import gunicorn; print('Gunicorn installed successfully')"

# Copy application code
COPY . .

# Create non-root user
RUN useradd --create-home --shell /bin/bash app
RUN chown -R app:app /app
USER app

# Expose port
EXPOSE 8001

# Use gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:8001", "--workers", "1", "--timeout", "120", "app:app"]