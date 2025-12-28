import { FastifyInstance } from 'fastify';
import { handleWebhook } from './service';

const webhookHandler =
  (topic: string) =>
  async (request: any, reply: any) => {
    try {
      await handleWebhook({
        topic,
        rawBody: request.rawBody,
        payload: request.body,
        headers: {
          'x-wc-webhook-signature': request.headers['x-wc-webhook-signature'],
          'x-wc-webhook-id': request.headers['x-wc-webhook-id'],
        },
      });
      reply.code(202).send({ status: 'queued' });
    } catch (err: any) {
      reply.code(400).send({ error: err?.message ?? 'webhook error' });
    }
  };

export async function webhookRoutes(fastify: FastifyInstance) {
  fastify.post(
    '/webhooks/woocommerce/order-created',
    { config: { rawBody: true, rateLimit: { max: 100, timeWindow: '1 minute' } } },
    webhookHandler('order.created'),
  );
  fastify.post(
    '/webhooks/woocommerce/order-updated',
    { config: { rawBody: true, rateLimit: { max: 100, timeWindow: '1 minute' } } },
    webhookHandler('order.updated'),
  );
  fastify.post(
    '/webhooks/woocommerce/order-deleted',
    { config: { rawBody: true, rateLimit: { max: 100, timeWindow: '1 minute' } } },
    webhookHandler('order.deleted'),
  );
}
