FROM python:3.12-slim-bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy uv and uvx binaries directly into the system path
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Set environment variables for optimized Docker usage
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

# Establish the working directory
WORKDIR /app

RUN uv tool install "git+https://github.com/elastic/sourcerer.git@v2.0.1"

ADD config/sourcerer.yml sourcerer.yml

ENTRYPOINT /root/.local/bin/sourcerer