/*app.ts*/
import express, { Express } from 'express';
import type { Request, Response } from 'express';

import { createProxyMiddleware } from 'http-proxy-middleware';

import { createClient } from 'redis';

import { Logger } from "tslog";
const logger = new Logger({ name: "router", type: "json" });

const { ExpressPrometheusMiddleware } = require('@matteodisabatino/express-prometheus-middleware')

const defaultLabels = { region: process.env.REGION };

const promClient = require('prom-client');
promClient.register.setDefaultLabels(defaultLabels);

const metricTransactions = new promClient.Counter({
  name: 'transactions',
  help: 'number of transactions routed'
});
const metricSharesTraded = new promClient.Counter({
  name: 'shares_traded',
  help: 'Number of shares traded',
  labelNames: ['symbol', 'action']
});

const defaultMetricsCollectorConfig = 
{
  register: promClient.register
}

const epm = new ExpressPrometheusMiddleware(defaultMetricsCollectorConfig);

const PORT: number = parseInt(process.env.PORT || '9000');

const app: Express = express();


function setupRedis() {
  const client = createClient({
    url: `redis://${process.env.REDIS_HOST}`
  });

  client.on('error', (err) => console.error('Redis Client Error', err));

  client.connect();
  console.log('Connected to Redis successfully!');

  return client;
}
const redisClient = setupRedis();

function getRandomBoolean() {
  return Math.random() < 0.5;
}

function customRouter(req: any) {
  var host = "";
  var method = ""

  var sessionStatus = redisClient.get(`${req.query.customer_id}:trades`);
  redisClient.incr(`${req.query.customer_id}:trades`);

  metricTransactions.inc();
  //logger.info(req.query)
  if (req.query.shares >= 0) {
    metricSharesTraded.labels({ symbol: req.query.symbol, action: req.query.action }).inc(Number(req.query.shares));
  }
  else
    logger.warn(`negative shares`);

  if (req.query.service != null) {
    method = "service";
    host = `http://${req.query.service}:9003`;
  }
  else {
    if (req.query.flags != null && req.query.flags.includes("GOZERO"))
    {
      method = "flags";
      host = `http://${process.env.RECORDER_HOST_CANARY}:9003`;
    }
    else {
      if (process.env.RECORDER_HOST_2 == null) {
        method = "default";
        host = `http://${process.env.RECORDER_HOST_1}:9003`;
      }
      else
      {
        method = "random";
        if (getRandomBoolean())
          host = `http://${process.env.RECORDER_HOST_1}:9003`;
        else
          host = `http://${process.env.RECORDER_HOST_2}:9003`;
      }
    }
  }

  logger.info(`routing request to ${host} because of ${method}`);
  return host;
};

const proxyMiddleware = createProxyMiddleware<Request, Response>({
  router: customRouter,
  changeOrigin: true,
  proxyTimeout: 5000
})

app.use(express.json());

app.get('/health', (req, res) => {
  res.send("KERNEL OK")
});

app.use(epm.handler)

app.use('/', proxyMiddleware);

app.listen(PORT, () => {
  logger.info(`Listening for requests on http://localhost:${PORT}`);
});
