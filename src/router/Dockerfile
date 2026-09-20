FROM node:24-alpine

RUN mkdir -p /home/node/app/node_modules
WORKDIR /home/node/app

COPY package*.json ./
COPY tsconfig.json ./
COPY app.ts ./

RUN --mount=type=cache,target=/root/.npm npm install

EXPOSE 9000

CMD [ "npx", "ts-node", "app.ts"]
