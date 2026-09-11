FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY load.py .

ENV DD_TRACE_ENABLED=false
CMD ["python", "-u", "load.py"]
