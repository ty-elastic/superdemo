FROM node:20 as frontend

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends gettext-base && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app
WORKDIR /app

# Copy package.json and package-lock.json to the working directory
COPY trader-app/package*.json ./
# Install dependencies
RUN npm install

COPY trader-app/src src
COPY trader-app/public public

RUN npm run build

CMD rm -rf /build/* && cp -r /app/build/. /build/
