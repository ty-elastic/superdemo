FROM python:3.12.6-slim-bookworm
RUN apt-get update && apt-get install -y curl git && rm -rf /var/lib/apt/lists/*
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

WORKDIR /python-docker

RUN git clone https://github.com/elastic/observability-migration-platform.git
WORKDIR /python-docker/observability-migration-platform

RUN pip install -e ".[all]"
RUN pip install uv
RUN obs-migrate --help

ENV PYTHONUNBUFFERED=1

ENTRYPOINT [ "obs-migrate" ]
