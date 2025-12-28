import crypto from 'crypto';
import { describe, expect, it } from 'vitest';
import { verifyWooSignature } from '../src/webhooks/service';

describe('verifyWooSignature', () => {
  it('validates WooCommerce signature with raw body', () => {
    const secret = 'secret';
    const rawBody = JSON.stringify({ foo: 'bar' });
    const signature = crypto.createHmac('sha256', secret).update(rawBody).digest('base64');
    expect(verifyWooSignature(rawBody, secret, signature)).toBe(true);
  });

  it('rejects invalid signatures', () => {
    const secret = 'secret';
    const rawBody = JSON.stringify({ foo: 'bar' });
    const signature = crypto.createHmac('sha256', secret).update(rawBody).digest('base64');
    expect(verifyWooSignature(rawBody, secret, signature + 'x')).toBe(false);
  });
});
