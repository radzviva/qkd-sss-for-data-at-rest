# qkd-simulator/Dockerfile
FROM python:3.9-slim

WORKDIR /app
# No extra dependencies needed for stdlib socket + json + random
COPY alice.py bob.py /app/

# Default command; overridden per service in Compose
CMD ["python", "alice.py"]
