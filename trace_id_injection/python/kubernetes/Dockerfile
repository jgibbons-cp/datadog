# syntax=docker/dockerfile:1

FROM python:3.13.0b1-slim

WORKDIR /app

RUN apt update && apt upgrade -y && apt install -y build-essential
RUN pip3 install ddtrace json_log_formatter
RUN apt remove -y build-essential

COPY trace_id_injection.py /app

CMD ["ddtrace-run", "python3", "trace_id_injection.py"]
