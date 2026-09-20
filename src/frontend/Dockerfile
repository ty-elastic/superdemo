FROM node:20 as frontend

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends gettext-base && \
    rm -rf /var/lib/apt/lists/*

ARG SERVICE_VERSION="1.0"
ARG SERVICE_NAME="trader-app-web"

RUN mkdir -p /app
WORKDIR /app

# Copy package.json and package-lock.json to the working directory
COPY trader-app/package*.json ./
# Install dependencies
RUN npm install

COPY trader-app/src src
COPY trader-app/public public
COPY telemetry.js .

RUN envsubst < telemetry.js > src/telemetry.js
RUN echo "import apm from './telemetry';\n" | cat - src/index.js > temp && mv temp src/index.js;

RUN npm run build

CMD rm -rf /build/* && cp -r /app/build/. /build/
