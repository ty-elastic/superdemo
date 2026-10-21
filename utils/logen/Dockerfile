FROM python:3.12.6-slim-bookworm
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /logen

COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip pip3 install --root-user-action=ignore --upgrade -r requirements.txt

COPY src src
COPY logs logs

ENV PYTHONUNBUFFERED=1

EXPOSE 9003
CMD [ "flask", "--app", "src/app", "run", "--host=0.0.0.0", "-p", "9003"]
