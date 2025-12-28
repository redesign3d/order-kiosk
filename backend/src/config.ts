import dotenv from 'dotenv';

dotenv.config();

const toInt = (value: string | undefined, fallback: number) =>
  value ? parseInt(value, 10) : fallback;

export const config = {
  env: process.env.NODE_ENV ?? 'development',
  port: toInt(process.env.PORT, 3000),
  databaseUrl:
    process.env.DATABASE_URL ??
    'postgresql://postgres:postgres@localhost:5432/orderkiosk',
  frontendOrigin: process.env.FRONTEND_ORIGIN ?? 'http://localhost:8080',
  jwtSecret: process.env.JWT_SECRET ?? 'dev-secret-change-me',
  sessionCookieName: process.env.SESSION_COOKIE_NAME ?? 'ok_session',
  sessionTtlHours: toInt(process.env.SESSION_TTL_HOURS, 24),
  encryptionKey: process.env.APP_ENCRYPTION_KEY,
  rateLimit: {
    max: toInt(process.env.RATE_LIMIT_MAX, 100),
    timeWindow: process.env.RATE_LIMIT_WINDOW ?? '1 minute',
  },
  webhookQueueConcurrency: toInt(process.env.WEBHOOK_QUEUE_CONCURRENCY, 3),
  wooApiVersion: process.env.WOO_API_VERSION ?? 'wc/v3',
  logLevel: process.env.LOG_LEVEL ?? 'info',
};

export const isProduction = config.env === 'production';
