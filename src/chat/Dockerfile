FROM python:3.13.14

WORKDIR /python-docker

COPY requirements-edot.txt .
COPY app app

RUN pip install --upgrade pip
RUN pip install -r requirements-edot.txt

RUN opentelemetry-bootstrap -a install

EXPOSE 8000

CMD ["opentelemetry-instrument", "--service_name", "chat", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--app-dir", "/python-docker", "--reload"]