import { User, Session, PrismaClient } from '@prisma/client';

declare module 'fastify' {
  interface FastifyRequest {
    user?: User;
    session?: Session;
    rawBody?: string | Buffer;
  }

  interface FastifyInstance {
    prisma: PrismaClient;
  }
}
