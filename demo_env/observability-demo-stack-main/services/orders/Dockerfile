# ----------------------------------------------------------------- build stage
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q package -DskipTests

# ---------------------------------------------------------------- runtime stage
FROM eclipse-temurin:17-jre
WORKDIR /app

# Datadog Java tracer: APM, runtime metrics, continuous profiler, DBM linkage.
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && curl -fsSL https://dtdg.co/latest-java-tracer -o /app/dd-java-agent.jar \
    && test -s /app/dd-java-agent.jar \
    && head -c 2 /app/dd-java-agent.jar | grep -q PK \
    && apt-get purge -y curl && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

COPY --from=build /build/target/orders.jar /app/orders.jar

ENV DD_TRACE_ENABLED=true \
    DD_RUNTIME_METRICS_ENABLED=true \
    DD_PROFILING_ENABLED=true \
    DD_LOGS_INJECTION=true \
    DD_DBM_PROPAGATION_MODE=full \
    DD_TRACE_DEBUG=false

EXPOSE 8080
# -javaagent lives on the command line, not in JAVA_TOOL_OPTIONS, so that
# setting JAVA_TOOL_OPTIONS elsewhere cannot silently disable APM.
ENTRYPOINT ["java", "-javaagent:/app/dd-java-agent.jar", "-jar", "/app/orders.jar"]
