"""FastAPI backend for the otel-genai-chat-app.

Endpoints:
  POST /api/chat   — SSE stream of assistant tokens
  GET  /healthz    — liveness check

OTel tracing is injected at process start via `opentelemetry-instrument`
(run-vanilla.sh / run-edot.sh / Makefile), so no manual span code is needed.
The instrumentation produces:
  - gen_ai.* spans for every OpenAI Chat Completions call (model, token usage,
    prompt/response events when OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=true)
  - HTTP server spans for each incoming request (FastAPI instrumentation)
"""

from __future__ import annotations

import json
import logging
from typing import AsyncGenerator

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from .config import config
from .openai_client import get_client

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

# Validate config at startup — fail fast with a clear message
config.validate()

app = FastAPI(title="otel-genai-chat-app", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=config.cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Request / Response models ─────────────────────────────────────────────────

class Message(BaseModel):
    role: str   # "user" | "assistant" | "system"
    content: str


class ChatRequest(BaseModel):
    messages: list[Message]
    model: str | None = None   # overrides OPENAI_MODEL when provided

    subscription: str | None = None
    customer_id: str | None = None
    region: str | None = None
    data_source: str | None = None

# ── SSE helpers ───────────────────────────────────────────────────────────────


async def _stream_chat(messages: list[Message], model: str, customer_id: str = None, region: str = None) -> AsyncGenerator[str, None]:
    """Yield SSE-formatted chunks from the OpenAI streaming response."""
    openai_messages = [{"role": m.role, "content": m.content} for m in messages]

    try:
        client = get_client(customer_id, region)
        stream = client.chat.completions.create(
            model=model,
            messages=openai_messages,  # type: ignore[arg-type]
            stream=True,
            stream_options={"include_usage": True},  # gives gen_ai.usage.* in OTel span
        )
        for chunk in stream:
            #log.info(chunk)
            if chunk.choices and chunk.choices[0].delta.content:
                yield f"data: {json.dumps({'content': chunk.choices[0].delta.content})}\n\n"
    except Exception as exc:
        log.error("OpenAI streaming error: %s", exc)
        yield f"data: {json.dumps({'error': str(exc)})}\n\n"

    yield "data: [DONE]\n\n"


# ── Routes ────────────────────────────────────────────────────────────────────

@app.post("/api/chat")
async def chat(body: ChatRequest) -> StreamingResponse:
    """Stream assistant tokens as Server-Sent Events."""
    if not body.messages:
        raise HTTPException(status_code=422, detail="messages must not be empty")

    model = body.model or config.openai_model
    customer_id = body.customer_id or None
    region = body.region or None

    log.info("Chat request: model=%s, customer_id=%s, region=%s", model, customer_id, region)

    return StreamingResponse(
        _stream_chat(body.messages, model, customer_id, region),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",  # disable Nginx buffering for SSE
        },
    )


@app.get("/healthz")
async def healthz() -> dict:
    return {"status": "ok", "model": config.openai_model}
