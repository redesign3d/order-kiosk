import { OrderStatus } from '@prisma/client';
import PQueue from 'p-queue';
import { config } from '../config';
import { prisma } from '../db';
import { logger } from '../logger';
import { deleteOrder, upsertWooOrder } from '../orders/service';
import { buildWooClient, getDecryptedSettings } from '../settings/service';

const queue = new PQueue({ concurrency: config.webhookQueueConcurrency });

export const enqueueOrderSync = (orderId: number, deliveryId?: number) =>
  queue
    .add(async () => {
      const client = await buildWooClient();
      const order = await client.fetchOrder(orderId);
      await upsertWooOrder(order);
      if (deliveryId) {
        await prisma.webhookDelivery.update({
          where: { id: deliveryId },
          data: { status: 'processed', processedAt: new Date() },
        });
      }
    })
    .catch(async (err) => {
      if (deliveryId) {
        await prisma.webhookDelivery.update({
          where: { id: deliveryId },
          data: { status: 'error', error: err?.message ?? 'unknown', processedAt: new Date() },
        });
      }
      throw err;
    });

export const runBackfill = async () => {
  const settings = await getDecryptedSettings();
  if (!settings) throw new Error('Settings not configured');

  const client = await buildWooClient();
  const statuses = settings.includeDrafts
    ? ['pending', 'processing', 'completed', 'cancelled', 'refunded', 'checkout-draft']
    : ['pending', 'processing', 'completed', 'cancelled', 'refunded'];

  let page = 1;
  const perPage = 50;
  let imported = 0;

  // eslint-disable-next-line no-constant-condition
  while (true) {
    const orders = await client.listOrders({
      page,
      per_page: perPage,
      status: statuses,
      orderby: 'date_modified',
      order: 'desc',
    });
    if (!orders.length) break;
    for (const order of orders) {
      await upsertWooOrder(order);
      imported += 1;
    }
    if (orders.length < perPage) break;
    page += 1;
  }

  logger.info({ imported }, 'Backfill complete');
  return imported;
};

export const enqueueOrderDeletion = (orderId: number, deliveryId?: number) =>
  queue
    .add(async () => {
      await deleteOrder(orderId);
      if (deliveryId) {
        await prisma.webhookDelivery.update({
          where: { id: deliveryId },
          data: { status: 'processed', processedAt: new Date() },
        });
      }
    })
    .catch(async (err) => {
      if (deliveryId) {
        await prisma.webhookDelivery.update({
          where: { id: deliveryId },
          data: { status: 'error', error: err?.message ?? 'unknown', processedAt: new Date() },
        });
      }
      throw err;
    });
