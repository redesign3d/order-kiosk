import crypto from 'crypto';
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { buildServer } from '../src/server';
import { prisma } from '../src/db';
import { encryptText } from '../src/utils/crypto';

describe('Webhook integration', () => {
  const webhookSecret = 'secret123';
  let app: Awaited<ReturnType<typeof buildServer>>;

  beforeAll(async () => {
    await prisma.$connect();
    await prisma.webhookDelivery.deleteMany();
    await prisma.orderItem.deleteMany();
    await prisma.order.deleteMany();
    await prisma.appSettings.upsert({
      where: { id: 1 },
      update: {
        storeUrl: 'https://example.test',
        consumerKeyEncrypted: encryptText('ck_123'),
        consumerSecretEncrypted: encryptText('cs_123'),
        webhookSecretEncrypted: encryptText(webhookSecret),
        includeDrafts: false,
        pollingIntervalSeconds: 15,
      },
      create: {
        id: 1,
        storeUrl: 'https://example.test',
        consumerKeyEncrypted: encryptText('ck_123'),
        consumerSecretEncrypted: encryptText('cs_123'),
        webhookSecretEncrypted: encryptText(webhookSecret),
        includeDrafts: false,
        pollingIntervalSeconds: 15,
      },
    });
    app = await buildServer();
  });

  afterAll(async () => {
    await app.close();
    await prisma.$disconnect();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('queues webhook and upserts order', async () => {
    const orderPayload = {
      id: 1001,
      number: '1001',
      status: 'processing',
      currency: 'USD',
      total: '25.00',
      customer_note: 'Leave at door',
      billing: { first_name: 'Sam', last_name: 'Lee', email: 'sam@example.com' },
      line_items: [{ id: 1, name: 'Widget', quantity: 1, total: '25.00', sku: 'W-1' }],
      date_created: new Date().toISOString(),
      date_modified: new Date().toISOString(),
    };

    vi.spyOn(global, 'fetch').mockResolvedValue({
      ok: true,
      json: async () => orderPayload,
    } as any);

    const rawBody = JSON.stringify(orderPayload);
    const signature = crypto.createHmac('sha256', webhookSecret).update(rawBody).digest('base64');

    const res = await app.inject({
      method: 'POST',
      url: '/webhooks/woocommerce/order-updated',
      payload: orderPayload,
      headers: {
        'x-wc-webhook-signature': signature,
        'x-wc-webhook-id': '1',
      },
    });

    expect(res.statusCode).toBe(202);

    await new Promise((resolve) => setTimeout(resolve, 50));

    const order = await prisma.order.findUnique({
      where: { id: 1001 },
      include: { items: true },
    });

    expect(order).toBeTruthy();
    expect(order?.items.length).toBe(1);
  });
});
