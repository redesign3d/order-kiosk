import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { buildServer } from '../src/server';
import { prisma } from '../src/db';
import { createUser, hashPassword } from '../src/auth/service';

describe('Auth routes', () => {
  let app: Awaited<ReturnType<typeof buildServer>>;
  const email = 'admin@test.com';
  const password = 'Password123!';

  beforeAll(async () => {
    await prisma.$connect();
    await prisma.session.deleteMany();
    await prisma.user.deleteMany();
    await createUser({ email, password });
    app = await buildServer();
  });

  afterAll(async () => {
    await app.close();
    await prisma.$disconnect();
  });

  it('logs in and returns user with csrf token', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email, password },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json() as any;
    expect(body.user.email).toBe(email);
    expect(body.csrfToken).toBeTruthy();
    const cookie = res.cookies.find((c) => c.name === 'ok_session');
    expect(cookie).toBeTruthy();

    const me = await app.inject({
      method: 'GET',
      url: '/api/auth/me',
      cookies: { ok_session: cookie!.value },
    });
    expect(me.statusCode).toBe(200);
    expect((me.json() as any).user.email).toBe(email);
  });
});
