FROM python:3.12.6-slim-bookworm
RUN apt-get update && apt-get install -y curl git && rm -rf /var/lib/apt/lists/*

WORKDIR /python-docker

RUN git clone -b master --single-branch --depth 1 https://github.com/lextudio/snmpsim-data.git 

RUN git clone -b master --single-branch --depth 1 --recurse-submodules https://github.com/lextudio/snmpsim.git
WORKDIR /python-docker/snmpsim

RUN pip install uv
RUN pip install pysmi

RUN pip install .

RUN adduser --system snmpsim

COPY data data 
RUN cp -f -r /python-docker/snmpsim-data/snmpsim_data/data/. data/ 

RUN mkdir -p /python-docker/snmpsim/cache
RUN chmod a+rwx /python-docker/snmpsim/cache

RUN snmpsim-command-responder --process-user=snmpsim --process-group=nogroup --data-dir=/python-docker/snmpsim/data --cache-dir=/python-docker/snmpsim/cache || true

ENV PYTHONUNBUFFERED=1

EXPOSE 161/udp

ENTRYPOINT [ "snmpsim-command-responder", "--agent-udpv4-endpoint=0.0.0.0:161", "--process-user=snmpsim", "--process-group=nogroup", "--data-dir=/python-docker/snmpsim/data", "--cache-dir=/python-docker/snmpsim/cache"]
