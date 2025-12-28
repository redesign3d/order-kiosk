import { FastifyInstance } from 'fastify';
import { OrderStatus } from '@prisma/client';
import { z } from 'zod';
import { requireAuth } from '../auth/middleware';
import { getOrder, listOrders } from './service';

const listQuery = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
  status: z.string().optional(),
  search: z.string().optional(),
  dateFrom: z.string().datetime().optional(),
  dateTo: z.string().datetime().optional(),
  sort: z.enum(['created', 'updated']).optional(),
  modified_after: z.string().datetime().optional(),
});

export async function orderRoutes(fastify: FastifyInstance) {
  fastify.get(
    '/api/orders',
    { preHandler: requireAuth({ requireCsrf: false }) },
    async (request, reply) => {
      const parsed = listQuery.safeParse(request.query);
      if (!parsed.success) {
        reply.code(400).send({ error: 'Invalid query' });
        return;
      }
      const { page, pageSize, status, search, dateFrom, dateTo, sort, modified_after } =
        parsed.data;
      const allowedStatuses = new Set(Object.values(OrderStatus));
      const statuses = status
        ? status
            .split(',')
            .map((s) => s.toUpperCase() as OrderStatus)
            .filter((s) => allowedStatuses.has(s))
        : undefined;
      const result = await listOrders({
        page,
        pageSize,
        status: statuses,
        search: search ?? undefined,
        dateFrom: dateFrom ? new Date(dateFrom) : undefined,
        dateTo: dateTo ? new Date(dateTo) : undefined,
        sort: sort ?? 'updated',
        modifiedAfter: modified_after ? new Date(modified_after) : undefined,
      });
      reply.send(result);
    },
  );

  fastify.get(
    '/api/orders/:id',
    { preHandler: requireAuth({ requireCsrf: false }) },
    async (request, reply) => {
      const id = Number((request.params as any).id);
      if (Number.isNaN(id)) {
        reply.code(400).send({ error: 'Invalid id' });
        return;
      }
      const order = await getOrder(id);
      if (!order) {
        reply.code(404).send({ error: 'Not found' });
        return;
      }
      reply.send(order);
    },
  );
}
