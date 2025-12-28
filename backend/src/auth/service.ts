import crypto from 'crypto';
import argon2 from 'argon2';
import { Prisma, Session, User, UserRole } from '@prisma/client';
import { prisma } from '../db';
import { config } from '../config';
import { hashToken } from '../utils/crypto';

const sessionExpiry = () =>
  new Date(Date.now() + config.sessionTtlHours * 60 * 60 * 1000);

export const hashPassword = async (password: string) => argon2.hash(password);
export const verifyPassword = async (hash: string, password: string) =>
  argon2.verify(hash, password);

export const findUserByEmail = (email: string) =>
  prisma.user.findUnique({ where: { email } });

export const createUser = async (input: {
  email: string;
  password: string;
  role?: UserRole;
}) => {
  const passwordHash = await hashPassword(input.password);
  return prisma.user.create({
    data: {
      email: input.email.toLowerCase(),
      passwordHash,
      role: input.role ?? UserRole.ADMIN,
    },
  });
};

export const ensureAdminUser = async (email: string, password: string) => {
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) return existing;
  return createUser({ email, password, role: UserRole.ADMIN });
};

export const createSession = async (user: User) => {
  const token = crypto.randomBytes(32).toString('hex');
  const csrfToken = crypto.randomBytes(16).toString('hex');
  const tokenHash = hashToken(token);
  const expiresAt = sessionExpiry();
  const session = await prisma.session.create({
    data: {
      userId: user.id,
      tokenHash,
      csrfToken,
      expiresAt,
    },
    include: { user: true },
  });
  return { token, csrfToken, session };
};

export const findSession = async (token: string) => {
  const tokenHash = hashToken(token);
  const session = await prisma.session.findUnique({
    where: { tokenHash },
    include: { user: true },
  });
  if (!session) return null;
  if (session.expiresAt < new Date()) {
    await prisma.session.delete({ where: { tokenHash } });
    return null;
  }
  await prisma.session.update({
    where: { tokenHash },
    data: { lastUsedAt: new Date() },
  });
  return session;
};

export const revokeSession = (token: string) =>
  prisma.session.delete({ where: { tokenHash: hashToken(token) } }).catch(() => null);

export const revokeUserSessions = (userId: string) =>
  prisma.session.deleteMany({ where: { userId } });

export const serializeUser = (user: User) => ({
  id: user.id,
  email: user.email,
  role: user.role,
  createdAt: user.createdAt,
  lastLoginAt: user.lastLoginAt,
});
