#!/usr/bin/env bash
# Start the backend with vanilla upstream OpenTelemetry instrumentation.
# Uses the .venv-vanilla virtualenv created by `make setup-vanilla`.
#
# Emits standard gen_ai.* OpenTelemetry semantic-convention spans and HTTP
# server spans.  Content capture is controlled by
# OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT in your .env.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VENV="$SCRIPT_DIR/.venv-vanilla"

if [[ ! -d "$VENV" ]]; then
  echo "❌  .venv-vanilla not found. Run: make setup-vanilla"
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

echo "▶  Starting backend (vanilla OTel) — OTLP → $OTEL_EXPORTER_OTLP_ENDPOINT"
echo "   Service:     ${OTEL_SERVICE_NAME:-otel-genai-chat-app}"
echo "   Environment: $OTEL_DEPLOYMENT_ENVIRONMENT"
echo "   Model:       ${OPENAI_MODEL:-gpt-4o-mini}"

"$VENV/bin/opentelemetry-instrument" \
  --service_name "${OTEL_SERVICE_NAME:-otel-genai-chat-app}" \
  "$VENV/bin/uvicorn" app.main:app \
    --host 0.0.0.0 \
    --port 8000 \
    --app-dir "$SCRIPT_DIR" \
    --reload
