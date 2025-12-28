import crypto from 'crypto';
import { prisma } from '../db';
import { logger } from '../logger';
import { getDecryptedSettings } from '../settings/service';
import { enqueueOrderDeletion, enqueueOrderSync } from '../sync/service';

type WebhookHeaders = {
  'x-wc-webhook-signature'?: string;
  'x-wc-webhook-id'?: string;
};

export const verifyWooSignature = (
  rawBody: string | Buffer,
  secret: string,
  signature?: string,
) => {
  if (!signature) return false;
  const digest = crypto
    .createHmac('sha256', secret)
    .update(typeof rawBody === 'string' ? rawBody : rawBody.toString('utf8'))
    .digest('base64');
  const provided = Buffer.from(signature);
  const expected = Buffer.from(digest);
  if (provided.length !== expected.length) return false;
  return crypto.timingSafeEqual(expected, provided);
};

const extractOrderId = (payload: any): number | null => {
  if (!payload) return null;
  if (typeof payload.id === 'number') return payload.id;
  if (typeof payload.resource_id === 'number') return payload.resource_id;
  return null;
};

export const handleWebhook = async (params: {
  topic: string;
  rawBody: string | Buffer | undefined;
  payload: any;
  headers: WebhookHeaders;
}) => {
  const settings = await getDecryptedSettings();
  if (!settings) throw new Error('Settings not configured');
  if (!params.rawBody) throw new Error('Missing raw body for signature verification');

  const signature = params.headers['x-wc-webhook-signature'];
  const wooDeliveryId = params.headers['x-wc-webhook-id'];
  const signatureValid = verifyWooSignature(params.rawBody, settings.webhookSecret, signature);

  const existing =
    wooDeliveryId &&
    (await prisma.webhookDelivery.findUnique({
      where: { topic_wooDeliveryId: { topic: params.topic, wooDeliveryId } },
    }));

  if (existing && existing.status === 'processed') {
    logger.info({ wooDeliveryId, topic: params.topic }, 'Duplicate webhook ignored');
    return;
  }

  const delivery = wooDeliveryId
    ? existing
      ? await prisma.webhookDelivery.update({
          where: { topic_wooDeliveryId: { topic: params.topic, wooDeliveryId } },
          data: { signatureValid, status: 'received', receivedAt: new Date() },
        })
      : await prisma.webhookDelivery.create({
          data: {
            topic: params.topic,
            wooDeliveryId,
            signatureValid,
            status: 'received',
          },
        })
    : await prisma.webhookDelivery.create({
        data: {
          topic: params.topic,
          wooDeliveryId: null,
          signatureValid,
          status: 'received',
        },
      });

  if (!signatureValid) {
    logger.warn({ topic: params.topic, wooDeliveryId }, 'Invalid webhook signature');
    await prisma.webhookDelivery.update({
      where: { id: delivery.id },
      data: { status: 'invalid-signature', processedAt: new Date() },
    });
    throw new Error('Invalid signature');
  }

  const orderId = extractOrderId(params.payload);
  if (!orderId) {
    await prisma.webhookDelivery.update({
      where: { id: delivery.id },
      data: { status: 'missing-order-id', processedAt: new Date() },
    });
    throw new Error('Missing order id');
  }

  try {
    if (params.topic === 'order.deleted') {
      await prisma.webhookDelivery.update({
        where: { id: delivery.id },
        data: { status: 'queued-delete' },
      });
      enqueueOrderDeletion(orderId, delivery.id).catch((err) =>
        logger.error({ err, wooDeliveryId }, 'Failed to process delete webhook'),
      );
    } else {
      await prisma.webhookDelivery.update({
        where: { id: delivery.id },
        data: { status: 'queued' },
      });
      enqueueOrderSync(orderId, delivery.id).catch((err) =>
        logger.error({ err, wooDeliveryId }, 'Failed to process webhook'),
      );
    }
  } catch (err: any) {
    await prisma.webhookDelivery.update({
      where: { id: delivery.id },
      data: { status: 'error', error: err?.message ?? 'unknown', processedAt: new Date() },
    });
    throw err;
  }
};
