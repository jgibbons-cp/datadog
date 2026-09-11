FROM node:20-slim

WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev \
    && node -e "require('dd-trace'); console.log('dd-trace imports OK')" 

COPY server.js ./

# Load the Datadog tracer before any application code.
ENV NODE_OPTIONS="-r dd-trace/init"
ENV DD_TRACE_ENABLED=true \
    DD_LOGS_INJECTION=true \
    DD_PROFILING_ENABLED=true \
    DD_RUNTIME_METRICS_ENABLED=true

EXPOSE 3000
CMD ["node", "server.js"]
