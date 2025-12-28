import { PrismaClient } from '@prisma/client';
import { config } from './config';

export const prisma = new PrismaClient({
  datasourceUrl: config.databaseUrl,
  log: config.env === 'development' ? ['query', 'info', 'warn', 'error'] : ['error'],
});
