import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { generateKeyPair, SignJWT } from 'jose';
import { LocalTokenCipher, tokenContext, KMSTokenCipher } from '../src/token-cipher.js';
import { AppleIdentity } from '../src/apple-identity.js';

test('authenticated encryption binds owner, connection, environment and purpose', async () => {
  const cipher = new LocalTokenCipher(randomBytes(32));
  const value = randomBytes(40).toString('hex');
  const context = tokenContext('plaid', 'fixture-owner', 'fixture-connection', 'sandbox');
  const encrypted = await cipher.encrypt(value, context);
  assert.equal(encrypted.encryptedToken.includes(Buffer.from(value)), false);
  assert.equal(await cipher.decrypt(encrypted, context), value);
  for (const altered of [
    tokenContext('plaid', 'other-owner', 'fixture-connection', 'sandbox'),
    tokenContext('plaid', 'fixture-owner', 'other-connection', 'sandbox'),
    tokenContext('plaid', 'fixture-owner', 'fixture-connection', 'production'),
    tokenContext('apple', 'fixture-owner', 'fixture-connection', 'sandbox'),
  ]) await assert.rejects(cipher.decrypt(encrypted, altered), { code: 'TOKEN_DECRYPTION_FAILED' });
  encrypted.encryptedToken[20] ^= 1;
  await assert.rejects(cipher.decrypt(encrypted, context), { code: 'TOKEN_DECRYPTION_FAILED' });
});

test('KMS adapter forwards authenticated context and rejects unconfigured keys', async () => {
  const keyID = 'projects/fixture/locations/fixture/keyRings/fixture/cryptoKeys/fixture';
  const context = Buffer.from('synthetic owner context');
  const encryptedToken = randomBytes(64);
  const cipher = new KMSTokenCipher(keyID, {
    async encrypt(request) {
      assert.equal(request.name, keyID);
      assert.deepEqual(request.additionalAuthenticatedData, context);
      return [{ ciphertext: encryptedToken }];
    },
    async decrypt(request) {
      assert.deepEqual(request.additionalAuthenticatedData, context);
      return [{ plaintext: Buffer.from('synthetic value') }];
    },
  });
  assert.deepEqual(await cipher.encrypt('synthetic value', context), { keyID, encryptedToken });
  assert.equal(await cipher.decrypt({ keyID, encryptedToken }, context), 'synthetic value');
  await assert.rejects(cipher.decrypt({ keyID: 'other', encryptedToken }, context), { code: 'TOKEN_KEY_NOT_CONFIGURED' });
});

test('Apple identity verification checks signatures, audience, issuer, age and subject', async () => {
  const { publicKey, privateKey } = await generateKeyPair('RS256');
  const other = await generateKeyPair('RS256');
  const verifier = new AppleIdentity({ clientID: 'com.example.fixture', keys: publicKey });
  const now = Math.floor(Date.now() / 1000);
  async function sign(overrides = {}, key = privateKey) {
    return new SignJWT({ sub: 'fixture-owner', nonce: 'fixture-nonce', iss: 'https://appleid.apple.com',
      aud: 'com.example.fixture', iat: now, exp: now + 300, ...overrides })
      .setProtectedHeader({ alg: 'RS256' }).sign(key);
  }
  assert.equal((await verifier.verify(await sign(), { fresh: true })).sub, 'fixture-owner');
  for (const token of [await sign({ aud: 'wrong' }), await sign({ iss: 'https://example.invalid' }),
    await sign({ exp: now - 60 }), await sign({ iat: now - 1200 }), await sign({ sub: '' }),
    await sign({}, other.privateKey)]) {
    await assert.rejects(verifier.verify(token, { fresh: true }), { code: 'APPLE_IDENTITY_INVALID' });
  }
});
