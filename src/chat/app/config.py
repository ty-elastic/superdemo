"""Application configuration loaded from environment variables / .env file."""

from __future__ import annotations

import os

from dotenv import load_dotenv

# Load .env from the repo root (one level above backend/)
_root = os.path.join(os.path.dirname(__file__), "..", "..", ".env")
load_dotenv(_root)


class Config:
    # OpenAI-compatible provider
    openai_api_key: str = os.environ.get("OPENAI_API_KEY", "")
    openai_base_url: str | None = os.environ.get("OPENAI_BASE_URL") or None
    openai_model: str = os.environ.get("OPENAI_MODEL", "gpt-4o-mini")

    # Frontend CORS — allow Vite dev server and production builds
    cors_origins: list[str] = [
        "http://localhost:5173",  # Vite default
        "http://localhost:4173",  # Vite preview
        "http://localhost:3000",
    ]

    def validate(self) -> None:
        if not self.openai_api_key:
            raise RuntimeError(
                "OPENAI_API_KEY is not set. "
                "Copy .env.example to .env and fill in your API key."
            )


config = Config()
