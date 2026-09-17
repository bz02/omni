FROM python:3.11-slim
WORKDIR /app
COPY requirements-memory.txt ./
RUN pip install --no-cache-dir -r requirements-memory.txt && \
    groupadd --gid 1000 omni && \
    useradd --create-home --uid 10001 --gid 1000 --shell /bin/bash omni
COPY omni_memory ./omni_memory
COPY deploy/render/entrypoint.py /app/render_entrypoint.py
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
EXPOSE 10000
# Render mounts the persistent disk after build. The short bootstrap initializes
# its dedicated directory and drops to UID 10001 before loading the application.
USER root
ENTRYPOINT ["python", "/app/render_entrypoint.py"]
