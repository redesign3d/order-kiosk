import dotenv from 'dotenv';

process.env.NODE_ENV = 'test';
dotenv.config({ path: '.env.test' });

process.env.APP_ENCRYPTION_KEY =
  process.env.APP_ENCRYPTION_KEY ?? 'base64:dGhpcy1pcy1hLTMyLWJ5dGUtc2VjcmV0LWtleSEhISE=';
process.env.FRONTEND_ORIGIN = process.env.FRONTEND_ORIGIN ?? 'http://localhost:8080';
process.env.DATABASE_URL =
  process.env.DATABASE_URL ?? 'postgresql://postgres:postgres@localhost:5433/orderkiosk_test';
