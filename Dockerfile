FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=5000

WORKDIR /app

# Install runtime dependencies from the application source
COPY Phase1/QuakeWatch/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY Phase1/QuakeWatch/ .

# Ensure logs directory exists
RUN mkdir -p /app/logs

EXPOSE 5000

CMD ["python", "app.py"]
