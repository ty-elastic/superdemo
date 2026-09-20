FROM python:3.12.6-slim-bookworm
RUN apt-get update && apt-get install -y curl patch && rm -rf /var/lib/apt/lists/*

WORKDIR /python-docker

RUN --mount=type=cache,target=/root/.cache/pip pip3 install --root-user-action=ignore opentelemetry-processor-baggage

COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip pip3 install --root-user-action=ignore -r requirements.txt

# RUN --mount=type=cache,target=/root/.cache/pip edot-bootstrap --action=install
# RUN --mount=type=cache,target=/root/.cache/pip pip3 uninstall -y opentelemetry-instrumentation-click

ARG VARIANT=none

COPY app.py .
COPY model.py .

ENV ROUTER_ENDPOINT="http://router:9000/record"
ENV PYTHONUNBUFFERED=1

ENV OTEL_SERVICE_NAME="trader"
ENV OTEL_PYTHON_LOG_LEVEL="info"
ENV OTEL_PYTHON_LOG_CORRELATION="true"
ENV OTEL_EXPERIMENTAL_RESOURCE_DETECTORS="process_runtime"
ENV OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE="delta"
# ENV OTEL_EXPORTER_OTLP_METRICS_PROTOCOL="grpc"
# ENV OTEL_EXPORTER_OTLP_METRICS_INSECURE=true
# ENV OTEL_EXPORTER_OTLP_METRICS=true
ENV OTEL_LOGS_EXPORTER="otlp"

EXPOSE 9001
CMD [ "flask", "run", "--host=0.0.0.0", "-p", "9001" ]
