# orchestrator/Dockerfile
FROM python:3.10-slim
WORKDIR /app
COPY . .
RUN pip install pyyaml httpx
ENV PYTHONPATH=/app
ENTRYPOINT ["python", "-m", "orchestrator.orchestrator"]