import { config } from './config';
import { logger } from './logger';
import { buildServer } from './server';
import { ensureAdminUser } from './auth/service';

const host = process.env.HOST ?? '0.0.0.0';

async function start() {
  const app = await buildServer();
  const adminEmail = process.env.ADMIN_EMAIL ?? 'admin@example.com';
  const adminPassword = process.env.ADMIN_PASSWORD ?? 'ChangeMe123!';
  await ensureAdminUser(adminEmail, adminPassword);

  try {
    await app.listen({ port: config.port, host });
    logger.info(`Server listening on ${host}:${config.port}`);
  } catch (err) {
    logger.error(err);
    process.exit(1);
  }
}

start();
