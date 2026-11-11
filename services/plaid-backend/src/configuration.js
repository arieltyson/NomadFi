import { ServiceError, requiredString } from './security.js';

export function configuration(env) {
  const required = key => requiredString(env[key]);
  const environment = required('PLAID_ENVIRONMENT');
  if (!['sandbox', 'production'].includes(environment)) throw new ServiceError('INVALID_ENVIRONMENT');
  const hosted = env.NODE_ENV === 'production';
  if (environment === 'production' && (!hosted || env.HOSTED_DATA_ACCEPTANCE !== 'reviewed')) throw new ServiceError('HOSTED_ACCEPTANCE_REQUIRED');
  const encryptionMode = required('TOKEN_ENCRYPTION');
  if (!['kms', 'local'].includes(encryptionMode) || (hosted && encryptionMode !== 'kms')) throw new ServiceError('KMS_REQUIRED');
  const databaseURL = new URL(required('DATABASE_URL'));
  if (!['postgres:', 'postgresql:'].includes(databaseURL.protocol)) throw new ServiceError('INVALID_DATABASE');
  for (const key of ['sslmode', 'sslcert', 'sslkey', 'sslrootcert']) {
    if (databaseURL.searchParams.has(key)) throw new ServiceError('DATABASE_TLS_OVERRIDE_REJECTED');
  }
  const socket = databaseURL.searchParams.get('host')?.startsWith('/cloudsql/');
  const local = ['127.0.0.1', 'localhost', '[::1]'].includes(databaseURL.hostname);
  const rateKey = Buffer.from(required('RATE_HASH_KEY'), 'base64');
  if (rateKey.length !== 32) throw new ServiceError('INVALID_RATE_KEY');
  const allowedSubjects = required('APPLE_ALLOWED_SUBJECTS').split(',').map(value => value.trim()).filter(Boolean);
  if (!allowedSubjects.length) throw new ServiceError('OWNER_ALLOWLIST_REQUIRED');
  const port = Number(env.PORT ?? 8788);
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new ServiceError('INVALID_PORT');
  return {
    hosted, port, host: hosted ? '0.0.0.0' : '127.0.0.1',
    pool: { connectionString: databaseURL.toString(), max: 8, connectionTimeoutMillis: 10000,
      ssl: socket || (!hosted && local) ? false : { rejectUnauthorized: true, ...(env.DATABASE_CA ? { ca: env.DATABASE_CA } : {}) } },
    plaid: { environment, clientID: required('PLAID_CLIENT_ID'), secret: required('PLAID_SECRET') },
    apple: { clientID: required('APPLE_CLIENT_ID'), teamID: required('APPLE_TEAM_ID'),
      keyID: required('APPLE_KEY_ID'), privateKey: required('APPLE_PRIVATE_KEY').replaceAll('\\n', '\n') },
    encryptionMode, encryptionKey: encryptionMode === 'kms' ? required('KMS_KEY_NAME') : Buffer.from(required('LOCAL_TOKEN_KEY'), 'base64'),
    allowedSubjects, rateKey, redirectURI: required('PLAID_REDIRECT_URI'), webhookURL: required('PLAID_WEBHOOK_URL'),
    workerJobName: env.WORKER_JOB_NAME || undefined,
  };
}
