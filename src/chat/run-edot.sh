#!/usr/bin/env bash
# Start the backend with EDOT Python (Elastic Distribution of OpenTelemetry).
# Uses the .venv-edot virtualenv created by `make setup-edot`.
#
# EDOT enriches traces with extra Elastic-specific attributes and produces
# richer service maps and transaction names in Kibana APM compared to vanilla.
# Compare the two by running vanilla vs EDOT side-by-side.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VENV="$SCRIPT_DIR/.venv-edot"

if [[ ! -d "$VENV" ]]; then
  echo "❌  .venv-edot not found. Run: make setup-edot"
  exit 1
fi

# Load .env from repo root
if [[ -f "$REPO_ROOT/.env" ]]; then
  # shellcheck disable=SC2046
  export $(grep -v '^#' "$REPO_ROOT/.env" | grep -v '^$' | xargs)
fi

# Ensure OTEL_DEPLOYMENT_ENVIRONMENT is set — APM UI requires it for the
# environment filter.  Falls back to "development" if absent from .env.
export OTEL_DEPLOYMENT_ENVIRONMENT="${OTEL_DEPLOYMENT_ENVIRONMENT:-development}"

# Ensure telemetry.distro.name=elastic is present in OTEL_RESOURCE_ATTRIBUTES.
# This attribute tells the APM backend the SDK is EDOT, which enables enriched
# service maps, transaction names, and removes the "data not fully enriched" warning.
if [[ -z "${OTEL_RESOURCE_ATTRIBUTES:-}" ]]; then
  export OTEL_RESOURCE_ATTRIBUTES="telemetry.distro.name=elastic"
elif [[ "${OTEL_RESOURCE_ATTRIBUTES}" != *"telemetry.distro.name"* ]]; then
  export OTEL_RESOURCE_ATTRIBUTES="${OTEL_RESOURCE_ATTRIBUTES},telemetry.distro.name=elastic"
fi

# Enable latest experimental GenAI semconv if not already set.
# This switches opentelemetry-instrumentation-openai-v2 to the v_new code path which:
#   1. properly handles OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=SPAN_AND_EVENT
#   2. sets gen_ai.provider.name (new semconv) instead of gen_ai.system (old semconv)
#   3. is required for Kibana APM 9.x GenAI tab to show message content
export OTEL_SEMCONV_STABILITY_OPT_IN="${OTEL_SEMCONV_STABILITY_OPT_IN:-gen_ai_latest_experimental}"

echo "▶  Starting backend (EDOT Python) — OTLP → $OTEL_EXPORTER_OTLP_ENDPOINT"
echo "   Service:     ${OTEL_SERVICE_NAME:-otel-genai-chat-app}"
echo "   Environment: $OTEL_DEPLOYMENT_ENVIRONMENT"
echo "   Model:       ${OPENAI_MODEL:-gpt-4o-mini}"
echo "   Resources:   $OTEL_RESOURCE_ATTRIBUTES"
echo "   Semconv:     $OTEL_SEMCONV_STABILITY_OPT_IN"

"$VENV/bin/opentelemetry-instrument" \
  --service_name "${OTEL_SERVICE_NAME:-otel-genai-chat-app}" \
  "$VENV/bin/uvicorn" app.main:app \
    --host 0.0.0.0 \
    --port 8000 \
    --app-dir "$SCRIPT_DIR" \
    --reload
