import { FastifyReply, FastifyRequest } from 'fastify';
import { config, isProduction } from '../config';
import { createSession, findSession, revokeSession, serializeUser } from './service';

export const setSessionCookie = (reply: FastifyReply, token: string) => {
  reply.setCookie(config.sessionCookieName, token, {
    httpOnly: true,
    sameSite: 'lax',
    secure: isProduction,
    path: '/',
    maxAge: config.sessionTtlHours * 60 * 60,
  });
};

export const clearSessionCookie = (reply: FastifyReply) => {
  reply.clearCookie(config.sessionCookieName, { path: '/' });
};

type GuardOptions = {
  adminOnly?: boolean;
  requireCsrf?: boolean;
};

export const requireAuth =
  (options: GuardOptions = { requireCsrf: true }) =>
  async (request: FastifyRequest, reply: FastifyReply) => {
    const token = request.cookies?.[config.sessionCookieName];
    if (!token) {
      reply.code(401).send({ error: 'Unauthorized' });
      return;
    }

    const session = await findSession(token);
    if (!session) {
      reply.code(401).send({ error: 'Session expired' });
      return;
    }

    if (options.requireCsrf !== false && request.method !== 'GET') {
      const csrf = request.headers['x-csrf-token'];
      if (!csrf || csrf !== session.csrfToken) {
        reply.code(403).send({ error: 'Invalid CSRF token' });
        return;
      }
    }

    if (options.adminOnly && session.user.role !== 'ADMIN') {
      reply.code(403).send({ error: 'Admin only' });
      return;
    }

    request.user = session.user;
    request.session = session;
  };

export const handleLoginSuccess = async (
  reply: FastifyReply,
  sessionData: Awaited<ReturnType<typeof createSession>>,
) => {
  setSessionCookie(reply, sessionData.token);
  reply.send({ user: serializeUser(sessionData.session.user), csrfToken: sessionData.csrfToken });
};
