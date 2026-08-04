# 1. Use the slim variant for a smaller image footprint
FROM debian:12-slim

# 2. Prevent interactive prompts during package installation
ARG DEBIAN_FRONTEND=noninteractive

ENV COURSE=o11y--course--field--100-e2e--test
ENV ELASTICSEARCH_URL=""
ENV ELASTICSEARCH_APIKEY=""
ENV FLEET_URL=""
ENV KIBANA_URL=""
ENV INGEST_URL=""
ENV HTTP_AUTH=true
ENV REMOTE_ENDPOINT=true
ENV K3S=false
ENV ACCESS_PASSWORD="changeme"

# 4. Install required tools and dependencies cleanly
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl tar gpg \
    ca-certificates \
    gettext-base jq \
    openssh-client sshpass apache2-utils \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 \
    && chmod 700 get_helm.sh \
    && ./get_helm.sh

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

WORKDIR /superdemo

COPY agents agents
COPY assets assets
COPY k8s k8s
COPY utils utils

COPY build.sh .
COPY install/package.sh package.sh 

#ENV KUBECONFIG=/superdemo/.kube/kubeconfig

CMD /superdemo/package.sh