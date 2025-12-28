import crypto from 'crypto';
import { config } from '../config';
import { isProduction } from '../config';

const fallbackKey = crypto.createHash('sha256').update('development-key').digest();

const normalizeKey = (value?: string): Buffer => {
  if (!value) {
    if (isProduction) {
      throw new Error('APP_ENCRYPTION_KEY is required in production');
    }
    return fallbackKey;
  }

  const parseBuffer = (): Buffer => {
    if (value.startsWith('base64:')) {
      return Buffer.from(value.replace('base64:', ''), 'base64');
    }
    if (value.length === 64) {
      return Buffer.from(value, 'hex');
    }
    const utf = Buffer.from(value, 'utf-8');
    return utf;
  };

  const buf = parseBuffer();
  if (buf.length !== 32) {
    if (isProduction) {
      throw new Error('APP_ENCRYPTION_KEY must be 32 bytes (base64 or hex)');
    }
    return fallbackKey;
  }
  return buf;
};

export const encryptionKey = normalizeKey(config.encryptionKey);

export const encryptText = (plaintext: string): string => {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', encryptionKey, iv);
  const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${iv.toString('base64')}.${encrypted.toString('base64')}.${tag.toString('base64')}`;
};

export const decryptText = (payload: string): string => {
  const [ivB64, dataB64, tagB64] = payload.split('.');
  if (!ivB64 || !dataB64 || !tagB64) {
    throw new Error('Invalid encrypted payload');
  }
  const iv = Buffer.from(ivB64, 'base64');
  const data = Buffer.from(dataB64, 'base64');
  const tag = Buffer.from(tagB64, 'base64');
  const decipher = crypto.createDecipheriv('aes-256-gcm', encryptionKey, iv);
  decipher.setAuthTag(tag);
  const decrypted = Buffer.concat([decipher.update(data), decipher.final()]);
  return decrypted.toString('utf8');
};

export const hashToken = (token: string) =>
  crypto.createHash('sha256').update(token).digest('hex');
