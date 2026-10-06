import { ServiceError, requiredString } from './security.js';

const knownErrors = new Set(['ITEM_LOGIN_REQUIRED', 'ITEM_NOT_FOUND', 'INVALID_ACCESS_TOKEN',
  'TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION', 'PRODUCT_NOT_READY', 'RATE_LIMIT_EXCEEDED',
  'INVALID_PUBLIC_TOKEN']);
const endpoints = new Set(['/transactions/sync', '/accounts/get', '/item/get', '/item/remove',
  '/link/token/create', '/item/public_token/exchange', '/webhook_verification_key/get', '/item/webhook/update']);

export class PlaidClient {
  constructor({ environment, clientID, secret, fetcher = fetch }) {
    if (!['sandbox', 'production'].includes(environment)) throw new ServiceError('INVALID_ENVIRONMENT');
    this.environment = environment;
    this.clientID = requiredString(clientID);
    this.secret = requiredString(secret);
    this.fetcher = fetcher;
  }
  async request(path, fields) {
    if (!endpoints.has(path)) throw new ServiceError('INVALID_PROVIDER_ENDPOINT');
    try {
      const response = await this.fetcher(`https://${this.environment}.plaid.com${path}`, {
        method: 'POST', redirect: 'error', signal: AbortSignal.timeout(25000),
        headers: { 'Content-Type': 'application/json', 'Plaid-Version': '2020-09-14',
          'PLAID-CLIENT-ID': this.clientID, 'PLAID-SECRET': this.secret },
        body: JSON.stringify(fields),
      });
      let size = 0; const chunks = [];
      for await (const chunk of response.body) {
        size += chunk.length;
        if (size > 8 * 1024 * 1024) throw new ServiceError('PROVIDER_INVALID_DATA', 502);
        chunks.push(chunk);
      }
      const result = JSON.parse(Buffer.concat(chunks).toString('utf8'));
      if (!response.ok) throw new ServiceError(knownErrors.has(result.error_code) ? result.error_code : 'PLAID_UNAVAILABLE', 502);
      return result;
    } catch (error) {
      if (error instanceof ServiceError) throw error;
      throw new ServiceError('PLAID_UNAVAILABLE', 502);
    }
  }
}
