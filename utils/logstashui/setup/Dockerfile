FROM python:3.12.6-slim-bookworm
RUN apt-get update && apt-get install -y curl patch && rm -rf /var/lib/apt/lists/*

WORKDIR /python-docker

COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip pip3 install --root-user-action=ignore -r requirements.txt

COPY api.py .

ENV PYTHONUNBUFFERED=1

ENTRYPOINT [ "python",  "api.py" ]
