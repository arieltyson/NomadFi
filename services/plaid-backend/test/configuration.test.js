import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { configuration } from '../src/configuration.js';

function fixture(extra = {}) {
  return { PLAID_ENVIRONMENT: 'sandbox', TOKEN_ENCRYPTION: 'local', DATABASE_URL: 'postgres://localhost/fixture',
    RATE_HASH_KEY: randomBytes(32).toString('base64'), LOCAL_TOKEN_KEY: randomBytes(32).toString('base64'),
    APPLE_ALLOWED_SUBJECTS: 'fixture-owner', PLAID_CLIENT_ID: 'fixture', PLAID_SECRET: randomBytes(32).toString('hex'),
    APPLE_CLIENT_ID: 'fixture', APPLE_TEAM_ID: 'fixture', APPLE_KEY_ID: 'fixture', APPLE_PRIVATE_KEY: 'fixture',
    PLAID_REDIRECT_URI: 'https://example.test/oauth', PLAID_WEBHOOK_URL: 'https://example.test/webhook', ...extra };
}
test('local sandbox binds loopback and production data needs recorded acceptance and KMS', () => {
  const local = configuration(fixture()); assert.equal(local.host, '127.0.0.1'); assert.equal(local.pool.ssl, false);
  assert.throws(() => configuration(fixture({ PLAID_ENVIRONMENT: 'production' })), { code: 'HOSTED_ACCEPTANCE_REQUIRED' });
  assert.throws(() => configuration(fixture({ NODE_ENV: 'production' })), { code: 'KMS_REQUIRED' });
  const hosted = configuration(fixture({ NODE_ENV: 'production', PLAID_ENVIRONMENT: 'production', HOSTED_DATA_ACCEPTANCE: 'reviewed',
    TOKEN_ENCRYPTION: 'kms', KMS_KEY_NAME: 'projects/fixture/locations/test/keyRings/test/cryptoKeys/test' }));
  assert.equal(hosted.pool.ssl.rejectUnauthorized, true); assert.equal(hosted.host, '0.0.0.0');
});
test('missing owner allowlist and weak rate keys prevent startup', () => {
  assert.throws(() => configuration(fixture({ APPLE_ALLOWED_SUBJECTS: '' })));
  assert.throws(() => configuration(fixture({ RATE_HASH_KEY: 'weak' })), { code: 'INVALID_RATE_KEY' });
});
