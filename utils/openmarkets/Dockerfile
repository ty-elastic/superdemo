FROM ghcr.io/astral-sh/uv:debian-slim
RUN apt-get update && apt-get install -y curl git && rm -rf /var/lib/apt/lists/*

WORKDIR /python-docker

RUN git clone https://github.com/danchev/openmarkets.git
WORKDIR /python-docker/openmarkets

RUN uvx openmarkets

ENV PYTHONUNBUFFERED=1

ENTRYPOINT [ "uvx", "openmarkets", "--transport", "http", "--host", "0.0.0.0", "--port", "8080", "--no-http-auth-enabled", "--no-dns-rebinding-protection-enabled", "--http-allowed-hosts", "*:*", "--no-http-stateless"]


