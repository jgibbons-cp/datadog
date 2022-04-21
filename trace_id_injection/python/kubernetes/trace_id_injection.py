from ddtrace import patch_all; patch_all(logging=True)
from ddtrace import tracer
import json_log_formatter
import logging
import os
import sys

# Sets logs to JSON format when running in a container
root = logging.getLogger()
if os.environ.get('DD_AGENT_HOST') is not None:
    json_handler = logging.StreamHandler(sys.stdout)
    json_handler.setFormatter(json_log_formatter.JSONFormatter())
    root.handlers.clear()
    root.addHandler(json_handler)
logger = logging.getLogger('trace_id_injection')
logger.setLevel(logging.INFO)

@tracer.wrap()
def hello():
    logger.info('Hello World')

hello()
