import Fastify from 'fastify';
import { randomUUID } from 'crypto';
import rawBody from 'fastify-raw-body';
import cookie from '@fastify/cookie';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import sensible from '@fastify/sensible';
import formBody from '@fastify/formbody';
import { config } from './config';
import { logger, loggerOptions } from './logger';
import { prismaPlugin } from './plugins/prismaPlugin';
import { authRoutes } from './auth/routes';
import { settingsRoutes } from './settings/routes';
import { orderRoutes } from './orders/routes';
import { webhookRoutes } from './webhooks/routes';

export async function buildServer() {
  const app = Fastify({
    logger: loggerOptions,
    disableRequestLogging: config.env === 'test',
    genReqId: () => randomUUID(),
  });

  await app.register(rawBody, {
    field: 'rawBody',
    global: false,
    runFirst: true,
    encoding: 'utf8',
  });
  await app.register(sensible);
  await app.register(cookie);
  await app.register(formBody);
  await app.register(cors, {
    origin: config.frontendOrigin,
    credentials: true,
  });
  await app.register(helmet, { contentSecurityPolicy: false });
  await app.register(rateLimit, {
    max: config.rateLimit.max,
    timeWindow: config.rateLimit.timeWindow,
  });
  await app.register(prismaPlugin);

  app.addHook('onRequest', async (request, reply) => {
    reply.header('x-request-id', request.id);
  });

  app.get('/healthz', async () => ({ ok: true }));

  await app.register(authRoutes);
  await app.register(settingsRoutes);
  await app.register(orderRoutes);
  await app.register(webhookRoutes);

  return app;
}
