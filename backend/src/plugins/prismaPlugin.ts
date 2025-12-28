import fp from 'fastify-plugin';
import { prisma } from '../db';

export const prismaPlugin = fp(async (fastify) => {
  fastify.decorate('prisma', prisma);
  fastify.addHook('onClose', async () => {
    await prisma.$disconnect();
  });
});
