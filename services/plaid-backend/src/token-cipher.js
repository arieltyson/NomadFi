import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import { KeyManagementServiceClient } from '@google-cloud/kms';
import { ServiceError, requiredString } from './security.js';

export function tokenContext(purpose, userID, resourceID, environment) {
  return Buffer.from(JSON.stringify(['nomadfi', 1, purpose, userID, resourceID, environment]));
}

export class LocalTokenCipher {
  constructor(key, keyID = 'local-v1') {
    if (!Buffer.isBuffer(key) || key.length !== 32) throw new ServiceError('INVALID_ENCRYPTION_KEY');
    this.key = Buffer.from(key);
    this.keyID = keyID;
  }
  async encrypt(value, context) {
    requiredString(value);
    const nonce = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key, nonce);
    cipher.setAAD(context);
    const ciphertext = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
    return { keyID: this.keyID, encryptedToken: Buffer.concat([Buffer.from([1]), nonce, cipher.getAuthTag(), ciphertext]) };
  }
  async decrypt({ keyID, encryptedToken }, context) {
    try {
      if (keyID !== this.keyID || encryptedToken[0] !== 1 || encryptedToken.length < 30) throw new Error();
      const cipher = createDecipheriv('aes-256-gcm', this.key, encryptedToken.subarray(1, 13));
      cipher.setAAD(context);
      cipher.setAuthTag(encryptedToken.subarray(13, 29));
      return Buffer.concat([cipher.update(encryptedToken.subarray(29)), cipher.final()]).toString('utf8');
    } catch { throw new ServiceError('TOKEN_DECRYPTION_FAILED', 503); }
  }
}

export class KMSTokenCipher {
  constructor(keyID, client = new KeyManagementServiceClient()) {
    if (!/^projects\/[^/]+\/locations\/[^/]+\/keyRings\/[^/]+\/cryptoKeys\/[^/]+$/.test(keyID)) {
      throw new ServiceError('INVALID_KMS_KEY');
    }
    this.keyID = keyID;
    this.client = client;
  }
  async encrypt(value, context) {
    requiredString(value);
    const [response] = await this.client.encrypt({ name: this.keyID, plaintext: Buffer.from(value), additionalAuthenticatedData: context });
    if (!response.ciphertext) throw new ServiceError('TOKEN_ENCRYPTION_FAILED', 503);
    return { keyID: this.keyID, encryptedToken: Buffer.from(response.ciphertext) };
  }
  async decrypt({ keyID, encryptedToken }, context) {
    if (keyID !== this.keyID) throw new ServiceError('TOKEN_KEY_NOT_CONFIGURED', 503);
    const [response] = await this.client.decrypt({ name: keyID, ciphertext: encryptedToken, additionalAuthenticatedData: context });
    if (!response.plaintext) throw new ServiceError('TOKEN_DECRYPTION_FAILED', 503);
    return Buffer.from(response.plaintext).toString('utf8');
  }
}
