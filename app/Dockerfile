FROM python:3.11-slim

# (optional) install system deps your libs might need
# RUN apt-get update && apt-get install -y --no-install-recommends gcc && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV PYTHONUNBUFFERED=1
# Cloud Run will inject PORT; default to 8080 if you run locally
ENV PORT=8080 GUNICORN_WORKERS=2

# Use a shell so $PORT expands; bind 0.0.0.0 (required in Cloud Run)
CMD ["sh","-c","exec gunicorn -w ${GUNICORN_WORKERS} -b 0.0.0.0:${PORT} main:app"]

