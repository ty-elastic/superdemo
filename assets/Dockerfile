FROM python:3.12.6-slim-bookworm
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /python-docker

COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip pip3 install --root-user-action=ignore -r requirements.txt


COPY app.py .
COPY workflows workflows
COPY rules_enable rules_enable
COPY rules rules
COPY knowledge knowledge
COPY synthetics synthetics
COPY agents agents
COPY tools tools
COPY aliases aliases
COPY data_views data_views
COPY ml ml
COPY objects objects
COPY skills skills
COPY slos slos
COPY dashboards dashboards
COPY streams streams

ENV PYTHONUNBUFFERED=1

ENTRYPOINT [ "python", "app.py" ]
