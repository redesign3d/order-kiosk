import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireAuth } from '../auth/middleware';
import { buildWooClient, getSettings, sanitizeSettings, upsertSettings } from './service';
import { runBackfill } from '../sync/service';
import { logAudit } from '../audit/service';

const settingsSchema = z.object({
  storeUrl: z.string().url(),
  consumerKey: z.string().min(1).optional(),
  consumerSecret: z.string().min(1).optional(),
  webhookSecret: z.string().min(1).optional(),
  includeDrafts: z.boolean(),
  pollingIntervalSeconds: z.number().min(5).max(3600),
});

export async function settingsRoutes(fastify: FastifyInstance) {
  fastify.get(
    '/api/settings',
    { preHandler: requireAuth({ adminOnly: true, requireCsrf: false }) },
    async (_request, reply) => {
      const settings = await getSettings();
      reply.send({ settings: sanitizeSettings(settings) });
    },
  );

  fastify.put(
    '/api/settings',
    { preHandler: requireAuth({ adminOnly: true }) },
    async (request, reply) => {
      const parsed = settingsSchema.safeParse(request.body);
      if (!parsed.success) {
        reply.code(400).send({ error: 'Invalid settings payload' });
        return;
      }
      const saved = await upsertSettings(parsed.data);
      await logAudit({
        userId: request.user?.id,
        action: 'settings.update',
        metadata: { storeUrl: parsed.data.storeUrl, includeDrafts: parsed.data.includeDrafts },
      });
      reply.send({ settings: sanitizeSettings(saved) });
    },
  );

  fastify.post(
    '/api/settings/test-connection',
    { preHandler: requireAuth({ adminOnly: true }) },
    async (request, reply) => {
      const client = await buildWooClient();
      await client.testConnection();
      await logAudit({ userId: request.user?.id, action: 'settings.testConnection' });
      reply.send({ ok: true });
    },
  );

  fastify.post(
    '/api/sync/backfill',
    { preHandler: requireAuth({ adminOnly: true }) },
    async (request, reply) => {
      const imported = await runBackfill();
      await logAudit({ userId: request.user?.id, action: 'sync.backfill', metadata: { imported } });
      reply.send({ imported });
    },
  );
}
