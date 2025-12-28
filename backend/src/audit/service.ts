import { prisma } from '../db';

export const logAudit = (params: { userId?: string | null; action: string; metadata?: any }) =>
  prisma.auditLog.create({
    data: {
      userId: params.userId ?? null,
      action: params.action,
      metadata: params.metadata ?? {},
    },
  });
