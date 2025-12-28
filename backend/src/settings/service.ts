import { AppSettings } from '@prisma/client';
import { prisma } from '../db';
import { decryptText, encryptText } from '../utils/crypto';
import { WooClient } from '../woo/client';

export type DecryptedSettings = {
  storeUrl: string;
  consumerKey: string;
  consumerSecret: string;
  webhookSecret: string;
  includeDrafts: boolean;
  pollingIntervalSeconds: number;
};

export type SettingsUpdateInput = {
  storeUrl: string;
  consumerKey?: string;
  consumerSecret?: string;
  webhookSecret?: string;
  includeDrafts: boolean;
  pollingIntervalSeconds: number;
};

export const sanitizeSettings = (settings: AppSettings | null) =>
  settings
    ? {
        storeUrl: settings.storeUrl,
        includeDrafts: settings.includeDrafts,
        pollingIntervalSeconds: settings.pollingIntervalSeconds,
        hasCredentials: Boolean(settings.consumerKeyEncrypted && settings.consumerSecretEncrypted),
        hasWebhookSecret: Boolean(settings.webhookSecretEncrypted),
      }
    : null;

export const getSettings = async () => prisma.appSettings.findUnique({ where: { id: 1 } });

export const getDecryptedSettings = async (): Promise<DecryptedSettings | null> => {
  const settings = await getSettings();
  if (!settings) return null;
  return {
    storeUrl: settings.storeUrl,
    consumerKey: decryptText(settings.consumerKeyEncrypted),
    consumerSecret: decryptText(settings.consumerSecretEncrypted),
    webhookSecret: decryptText(settings.webhookSecretEncrypted),
    includeDrafts: settings.includeDrafts,
    pollingIntervalSeconds: settings.pollingIntervalSeconds,
  };
};

const resolveSecret = (nextValue: string | undefined, existing?: string | null) => {
  if (nextValue) return encryptText(nextValue);
  return existing ?? null;
};

export const upsertSettings = async (input: SettingsUpdateInput) => {
  const existing = await getSettings();

  const consumerKeyEncrypted = resolveSecret(input.consumerKey, existing?.consumerKeyEncrypted);
  const consumerSecretEncrypted = resolveSecret(
    input.consumerSecret,
    existing?.consumerSecretEncrypted,
  );
  const webhookSecretEncrypted = resolveSecret(
    input.webhookSecret,
    existing?.webhookSecretEncrypted,
  );

  if (!consumerKeyEncrypted || !consumerSecretEncrypted || !webhookSecretEncrypted) {
    throw new Error('Missing credentials or webhook secret');
  }

  const data = {
    storeUrl: input.storeUrl,
    consumerKeyEncrypted,
    consumerSecretEncrypted,
    webhookSecretEncrypted,
    includeDrafts: input.includeDrafts,
    pollingIntervalSeconds: input.pollingIntervalSeconds,
  };

  const saved = existing
    ? await prisma.appSettings.update({ where: { id: 1 }, data })
    : await prisma.appSettings.create({ data: { ...data, id: 1 } });

  return saved;
};

export const buildWooClient = async () => {
  const settings = await getDecryptedSettings();
  if (!settings) throw new Error('App settings not configured');
  return new WooClient(
    settings.storeUrl,
    settings.consumerKey,
    settings.consumerSecret,
  );
};
