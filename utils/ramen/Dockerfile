# 1. Use the slim variant for a smaller image footprint
FROM debian:13-slim as builder

WORKDIR /superdemo

RUN apt update
RUN apt install -y git cmake build-essential libjson-c-dev libwebsockets-dev

RUN git clone https://github.com/tsl0922/ttyd.git
RUN cd ttyd && mkdir build && cd build && cmake .. && make && make install
RUN which ttyd

FROM debian:13-slim as run

# 2. Prevent interactive prompts during package installation
ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /root

COPY --from=builder /usr/local/bin/ttyd /usr/local/bin/ttyd

# 4. Install required tools and dependencies cleanly
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl vim-tiny \
    ca-certificates \
    stress \
    libjson-c-dev libwebsockets-dev \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# RAMEN
RUN mkdir -p "/root/.config/elastic-ramen"
COPY AGENTS.md /root/.config/elastic-ramen/AGENTS.md
RUN mkdir -p "/root/.config/elastic"

RUN curl -fsSL https://raw.githubusercontent.com/elastic/elastic-ramen/dev/install | bash

RUN apt update
RUN apt install nodejs npm -y
RUN npm install -g @elastic/cli

ENTRYPOINT /usr/local/bin/ttyd -w /root --writable bash
