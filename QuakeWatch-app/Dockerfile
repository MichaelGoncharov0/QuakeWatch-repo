FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=5000

WORKDIR /app

# Install runtime dependencies
COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY . .

# Ensure logs directory exists
RUN mkdir -p /app/logs

EXPOSE 5000

CMD ["python", "app.py"]
