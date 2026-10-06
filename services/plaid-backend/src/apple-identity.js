import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from 'jose';
import { ServiceError, requiredString } from './security.js';

const issuer = 'https://appleid.apple.com';

export class AppleIdentity {
  constructor({ clientID, teamID, keyID, privateKey, fetcher = fetch,
    keys = createRemoteJWKSet(new URL(`${issuer}/auth/keys`)), clock = () => new Date() }) {
    this.clientID = requiredString(clientID, 256);
    this.teamID = teamID;
    this.keyID = keyID;
    this.privateKey = privateKey;
    this.fetcher = fetcher;
    this.keys = keys;
    this.clock = clock;
  }
  async verify(identityToken, { fresh = false } = {}) {
    try {
      const { payload } = await jwtVerify(requiredString(identityToken), this.keys, {
        algorithms: ['RS256', 'ES256'], issuer, audience: this.clientID,
        currentDate: this.clock(), clockTolerance: 5,
        requiredClaims: ['sub', 'iat', 'exp'], ...(fresh ? { maxTokenAge: '10m' } : {}),
      });
      if (typeof payload.sub !== 'string' || !payload.sub.length || payload.sub.length > 512) throw new Error();
      return payload;
    } catch { throw new ServiceError('APPLE_IDENTITY_INVALID', 401); }
  }
  async clientSecret() {
    const key = await importPKCS8(this.privateKey, 'ES256');
    const now = Math.floor(this.clock().getTime() / 1000);
    return new SignJWT({}).setProtectedHeader({ alg: 'ES256', kid: this.keyID })
      .setIssuer(this.teamID).setSubject(this.clientID).setAudience(issuer)
      .setIssuedAt(now).setExpirationTime(now + 300).sign(key);
  }
  async verifyNotification(token) {
    try {
      const { payload } = await jwtVerify(requiredString(token), this.keys, {
        algorithms: ['RS256', 'ES256'], issuer, audience: this.clientID,
        currentDate: this.clock(), clockTolerance: 5, requiredClaims: ['iat', 'jti', 'events'],
      });
      const event = typeof payload.events === 'string' ? JSON.parse(payload.events) : payload.events;
      const now = Math.floor(this.clock().getTime() / 1000);
      if (!Number.isSafeInteger(payload.iat) || payload.iat > now + 5 || !event
          || !Number.isSafeInteger(event.event_time) || event.event_time > now + 5 || event.event_time < 0
          || !['email-enabled', 'email-disabled', 'consent-revoked', 'account-deleted'].includes(event.type)) throw new Error();
      return { id: requiredString(payload.jti, 512), subject: requiredString(event.sub, 512),
        type: event.type, time: new Date(event.event_time * 1000) };
    } catch { throw new ServiceError('APPLE_NOTIFICATION_INVALID', 401); }
  }
  async request(path, fields) {
    let response;
    try {
      response = await this.fetcher(`${issuer}/auth/${path}`, {
        method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ ...fields, client_id: this.clientID, client_secret: await this.clientSecret() }),
        signal: AbortSignal.timeout(15000), redirect: 'error',
      });
    } catch { throw new ServiceError('APPLE_UNAVAILABLE', 503); }
    if (!response.ok) {
      let code;
      try { code = (await response.json()).error; } catch {}
      throw new ServiceError(code === 'invalid_grant' ? 'APPLE_GRANT_REVOKED' : 'APPLE_UNAVAILABLE',
        code === 'invalid_grant' ? 401 : 503);
    }
    return path === 'revoke' ? {} : response.json();
  }
  async redeem(code) {
    const result = await this.request('token', { grant_type: 'authorization_code', code: requiredString(code) });
    requiredString(result.refresh_token);
    return { identity: await this.verify(result.id_token, { fresh: true }), refreshToken: result.refresh_token };
  }
  async validateGrant(refreshToken, subject) {
    const result = await this.request('token', { grant_type: 'refresh_token', refresh_token: refreshToken });
    const identity = await this.verify(result.id_token);
    if (identity.sub !== subject) throw new ServiceError('APPLE_IDENTITY_INVALID', 401);
  }
  async revoke(refreshToken) {
    await this.request('revoke', { token: refreshToken, token_type_hint: 'refresh_token' });
  }
}
