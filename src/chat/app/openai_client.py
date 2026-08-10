"""OpenAI client factory.

Uses OPENAI_BASE_URL to support any OpenAI-compatible gateway (LiteLLM, Azure,
local models, etc.).  The openai-instrumentation-openai-v2 / EDOT instrumentation
wraps this client automatically when the process is started via
`opentelemetry-instrument` — no manual span code required here.
"""

from __future__ import annotations

import openai
import requests

from .config import config


_DEFAULT_BASE_URL = "https://api.openai.com/v1"


def make_client(user_id, team_id) -> openai.OpenAI:
    """Return a configured synchronous OpenAI client.

    Always pass base_url explicitly so the SDK never falls back to reading
    OPENAI_BASE_URL from the environment — an empty string there would cause
    "Request URL is missing an http:// or https:// protocol".
    """

    # Define your LiteLLM Proxy endpoint URL
    base_url=config.openai_base_url or _DEFAULT_BASE_URL
    proxy_url=base_url.removesuffix("/v1")
    proxy_api_key = config.openai_api_key

    # Define properties and access limits for the new virtual key
    payload = {
        "models": ["anthropic-claude-4.5-haiku", "mock-openai"],
        "key_alias": user_id,
        "user_id": user_id,
        "team_id": team_id
    }

    # Add authentication headers using the master key
    headers = {
        "Authorization": f"Bearer {proxy_api_key}",
        "Content-Type": "application/json"
    }

    # Send the request to create the virtual key
    response = requests.post(f"{proxy_url}/key/generate", json=payload, headers=headers)
    response.raise_for_status()
    
    # Parse and display the response JSON data
    key_data = response.json()

    print("Virtual Key Created Successfully!")
    print(f"Generated Key: {key_data.get('key')}")
    print(f"Expires: {key_data.get('expires')}")

    return openai.OpenAI(
        api_key=key_data.get('key'),
        base_url=config.openai_base_url or _DEFAULT_BASE_URL,
    )


# Module-level singleton — the OTel instrumentation patches openai.OpenAI so
# the singleton is instrumented as soon as the process starts.
#client = make_client()

clients = {}
def get_client(customer_id, region):
    if customer_id is None:
        customer_id = 'admin'
    if region is None:
        region = 'admin'

    if customer_id not in clients:
        clients[customer_id] = make_client(customer_id, region)
    return clients[customer_id]

