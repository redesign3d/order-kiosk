import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { config } from '../config';
import { requireAuth, clearSessionCookie, setSessionCookie } from './middleware';
import { createSession, findUserByEmail, serializeUser, verifyPassword, revokeSession } from './service';
import { logAudit } from '../audit/service';

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

export async function authRoutes(fastify: FastifyInstance) {
  fastify.post(
    '/api/auth/login',
    {
      config: { rateLimit: { max: 5, timeWindow: '1 minute' } },
    },
    async (request, reply) => {
      const parsed = loginSchema.safeParse(request.body);
      if (!parsed.success) {
        reply.code(400).send({ error: 'Invalid credentials' });
        return;
      }
      const { email, password } = parsed.data;
      const user = await findUserByEmail(email.toLowerCase());
      if (!user) {
        reply.code(401).send({ error: 'Invalid credentials' });
        return;
      }
      const valid = await verifyPassword(user.passwordHash, password);
      if (!valid) {
        reply.code(401).send({ error: 'Invalid credentials' });
        return;
      }
      const sessionData = await createSession(user);
      await fastify.prisma.user.update({
        where: { id: user.id },
        data: { lastLoginAt: new Date() },
      });
      await logAudit({ userId: user.id, action: 'auth.login' });
      setSessionCookie(reply, sessionData.token);
      reply.send({ user: serializeUser(user), csrfToken: sessionData.csrfToken });
    },
  );

  fastify.post(
    '/api/auth/logout',
    { preHandler: requireAuth({ requireCsrf: true }) },
    async (request, reply) => {
      const token = request.cookies?.[config.sessionCookieName];
      if (token) {
        await revokeSession(token);
      }
      clearSessionCookie(reply);
      reply.code(204).send();
    },
  );

  fastify.get(
    '/api/auth/me',
    { preHandler: requireAuth({ requireCsrf: false }) },
    async (request, reply) => {
      reply.send({ user: serializeUser(request.user!), csrfToken: request.session?.csrfToken });
    },
  );
}
