// config.js
// Pure broker configuration parser. Keeps the env-vars → typed-config
// translation isolated from the running Express server so the rules
// stay unit-testable. Imported by `server.js` at startup; also
// exercised by `config.test.js` via Node's built-in test runner.
//
// Two operating modes the broker exposes:
//
//   1. Sandbox (default).  PLAID_ENV=sandbox. Backed by Plaid's
//      sandbox endpoint per https://plaid.com/docs/sandbox/. The
//      `/sandbox/*` endpoints are available; production-only
//      pre-flight checks are skipped.
//
//   2. Live-data evaluation.  PLAID_ENV=production AND
//      PLAID_LIVE_DATA_EVALUATION=1. Backed by Plaid's production
//      endpoint per https://plaid.com/docs/api/. Requires:
//        - the developer to have been granted Plaid production /
//          Limited Production access for `com.arieljtyson.NomadFi`
//          via the Plaid Dashboard (Plaid-side permission, not
//          something this broker enforces);
//        - PLAID_REDIRECT_URI to be set, because OAuth-capable
//          institutions (most Canadian FIs per
//          https://plaid.com/en-ca/) will refuse to launch Link
//          without a valid HTTPS redirect URI matching the app's
//          associated-domains entitlement;
//        - LAN-mode shared-secret rules still apply.
//      Intentionally a separate flag from `PLAID_ENV=production`:
//      a forgotten env-var change should not silently move a
//      developer onto live data.
//
// Plaid's environment URLs are listed in the SDK's `PlaidEnvironments`
// constant; we accept only the two values the broker actually
// supports. `development` is deprecated in current Plaid docs and is
// not exposed here.
//
// Sources (vendor-reported unless explicitly regulator/standards):
// - https://plaid.com/docs/api/
// - https://plaid.com/docs/sandbox/
// - https://plaid.com/docs/link/oauth/

'use strict';

const SUPPORTED_ENVS = new Set(['sandbox', 'production']);
const MIN_SHARED_SECRET_LENGTH = 16;
const LOOPBACK_HOSTS = new Set(['127.0.0.1', '::1', 'localhost']);

/**
 * Parses raw env-var values into a typed broker configuration.
 *
 * Throws a structured error (`{ code, message }`) on invalid /
 * unsafe combinations so the running server can log a single
 * deterministic failure and exit. Tests assert on the `code`
 * field rather than message strings.
 *
 * @param {Record<string, string | undefined>} env
 * @returns {{
 *   port: number,
 *   plaidEnv: 'sandbox' | 'production',
 *   isLiveDataEvaluation: boolean,
 *   clientID: string,
 *   secret: string,
 *   countryCodesRaw: string,
 *   productsRaw: string,
 *   sandboxInstitutionID: string,
 *   redirectURI: string | null,
 *   bindHost: string,
 *   sharedSecret: string,
 *   isLoopbackMode: boolean,
 * }}
 */
function parseConfig(env) {
  const plaidEnv = (env.PLAID_ENV || 'sandbox').toLowerCase();
  if (!SUPPORTED_ENVS.has(plaidEnv)) {
    throw configError(
      'UNSUPPORTED_ENV',
      `PLAID_ENV must be one of ${[...SUPPORTED_ENVS].join(', ')}; got "${plaidEnv}".`
    );
  }

  const isLiveDataEvaluation = plaidEnv === 'production';
  if (isLiveDataEvaluation && env.PLAID_LIVE_DATA_EVALUATION !== '1') {
    throw configError(
      'LIVE_DATA_NOT_OPTED_IN',
      'PLAID_ENV=production requires PLAID_LIVE_DATA_EVALUATION=1. ' +
        'This is a deliberate, separate flag so a forgotten env change ' +
        'cannot silently move you onto live data.'
    );
  }

  const clientID = (env.PLAID_CLIENT_ID || '').trim();
  const secret = (env.PLAID_SECRET || '').trim();
  if (!clientID || !secret) {
    throw configError(
      'MISSING_PLAID_CREDENTIALS',
      'PLAID_CLIENT_ID and PLAID_SECRET are required.'
    );
  }

  const port = Number(env.PORT) || 8787;
  const countryCodesRaw = env.PLAID_COUNTRY_CODES || 'US';
  const productsRaw = env.PLAID_PRODUCTS || 'transactions';
  const sandboxInstitutionID =
    env.PLAID_SANDBOX_INSTITUTION_ID || 'ins_109508';
  const redirectURI = (env.PLAID_REDIRECT_URI || '').trim() || null;

  if (isLiveDataEvaluation && !redirectURI) {
    throw configError(
      'MISSING_REDIRECT_URI_FOR_PRODUCTION',
      'PLAID_REDIRECT_URI is required in production mode. Plaid Link ' +
        'requires an HTTPS redirect URI for OAuth-capable institutions; ' +
        'NomadFi uses https://arieltyson.github.io/nomadfi-privacy/plaid-oauth.'
    );
  }

  const bindHost = (env.PLAID_BROKER_BIND_HOST || '127.0.0.1').trim();
  const sharedSecret = (env.PLAID_BROKER_SHARED_SECRET || '').trim();
  const isLoopbackMode = LOOPBACK_HOSTS.has(bindHost);

  if (!isLoopbackMode && sharedSecret.length < MIN_SHARED_SECRET_LENGTH) {
    throw configError(
      'LAN_MODE_MISSING_SECRET',
      `LAN mode requires PLAID_BROKER_SHARED_SECRET (>= ${MIN_SHARED_SECRET_LENGTH} chars). ` +
        'Either set PLAID_BROKER_BIND_HOST back to 127.0.0.1 or generate a secret with `openssl rand -hex 32`.'
    );
  }

  return {
    port,
    plaidEnv,
    isLiveDataEvaluation,
    clientID,
    secret,
    countryCodesRaw,
    productsRaw,
    sandboxInstitutionID,
    redirectURI,
    bindHost,
    sharedSecret,
    isLoopbackMode,
  };
}

/**
 * Resolves a comma-separated env-var into a list of Plaid SDK enum
 * values, accepting any common casing. Unknown tokens are silently
 * dropped — Plaid will reject anything wrong at the API call.
 */
function parsePlaidEnumList(rawValue, enumObject) {
  return String(rawValue)
    .split(',')
    .map((token) => token.trim())
    .filter(Boolean)
    .map((token) => resolvePlaidEnumValue(token, enumObject))
    .filter(Boolean);
}

function resolvePlaidEnumValue(token, enumObject) {
  const exact = enumObject[token];
  if (exact) return exact;
  const lower = token.toLowerCase();
  const upper = token.toUpperCase();
  const pascal = lower.charAt(0).toUpperCase() + lower.slice(1);
  return enumObject[lower] || enumObject[upper] || enumObject[pascal] || null;
}

function configError(code, message) {
  const err = new Error(message);
  err.code = code;
  return err;
}

module.exports = {
  parseConfig,
  parsePlaidEnumList,
  resolvePlaidEnumValue,
  SUPPORTED_ENVS,
  MIN_SHARED_SECRET_LENGTH,
  LOOPBACK_HOSTS,
};
