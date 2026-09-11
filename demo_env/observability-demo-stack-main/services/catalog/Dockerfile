FROM python:3.11-slim

WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
# The second command fails the build rather than shipping an image whose tracer
# cannot import -- a missing ddtrace dependency is otherwise silent at runtime.
RUN pip install --no-cache-dir -r requirements.txt \
    && python -c "import ddtrace, wrapt; print('ddtrace', ddtrace.__version__, 'imports OK')"

COPY main.py .

ENV DD_TRACE_ENABLED=true \
    DD_LOGS_INJECTION=true \
    DD_PROFILING_ENABLED=true \
    DD_DBM_PROPAGATION_MODE=full \
    DD_RUNTIME_METRICS_ENABLED=true

EXPOSE 8000
# ddtrace-run auto-instruments FastAPI, psycopg2 and redis.
# No --workers: it forks a subprocess for no benefit at one worker, and the
# extra process boundary is a common source of missing instrumentation.
CMD ["ddtrace-run", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
