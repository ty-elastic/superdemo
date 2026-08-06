"""OpenAI client factory.

Uses OPENAI_BASE_URL to support any OpenAI-compatible gateway (LiteLLM, Azure,
local models, etc.).  The openai-instrumentation-openai-v2 / EDOT instrumentation
wraps this client automatically when the process is started via
`opentelemetry-instrument` — no manual span code required here.
"""

from __future__ import annotations

import openai

from .config import config


_DEFAULT_BASE_URL = "https://api.openai.com/v1"


def make_client() -> openai.OpenAI:
    """Return a configured synchronous OpenAI client.

    Always pass base_url explicitly so the SDK never falls back to reading
    OPENAI_BASE_URL from the environment — an empty string there would cause
    "Request URL is missing an http:// or https:// protocol".
    """
    return openai.OpenAI(
        api_key=config.openai_api_key,
        base_url=config.openai_base_url or _DEFAULT_BASE_URL,
    )


# Module-level singleton — the OTel instrumentation patches openai.OpenAI so
# the singleton is instrumented as soon as the process starts.
client = make_client()
