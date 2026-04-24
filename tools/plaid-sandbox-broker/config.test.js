// config.test.js
// Pure unit coverage for the broker's env-vars → typed-config
// parser. Runs under Node 20+'s built-in test runner: `npm test`.
// No network, no Plaid SDK calls — everything here exercises the
// pure rules from `config.js`.

'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');

const { parseConfig, parsePlaidEnumList, SUPPORTED_ENVS } = require('./config');

const baselineSandboxEnv = Object.freeze({
  PLAID_CLIENT_ID: 'sandbox_client_id_value',
  PLAID_SECRET: 'sandbox_secret_value',
  PLAID_ENV: 'sandbox',
  PLAID_COUNTRY_CODES: 'US,CA',
  PLAID_PRODUCTS: 'transactions,auth,balance',
  PLAID_BROKER_BIND_HOST: '127.0.0.1',
  PLAID_REDIRECT_URI: 'https://arieltyson.github.io/nomadfi-privacy/plaid-oauth',
});

const baselineProductionEnv = Object.freeze({
  ...baselineSandboxEnv,
  PLAID_CLIENT_ID: 'production_client_id_value',
  PLAID_SECRET: 'production_secret_value',
  PLAID_ENV: 'production',
  PLAID_LIVE_DATA_EVALUATION: '1',
});

// ---- Sandbox defaults ----------------------------------------------

test('sandbox config parses with defaults', () => {
  const cfg = parseConfig({
    PLAID_CLIENT_ID: 'cid',
    PLAID_SECRET: 'secret',
  });
  assert.equal(cfg.plaidEnv, 'sandbox');
  assert.equal(cfg.isLiveDataEvaluation, false);
  assert.equal(cfg.isLoopbackMode, true);
  assert.equal(cfg.bindHost, '127.0.0.1');
  assert.equal(cfg.port, 8787);
  assert.equal(cfg.redirectURI, null);
  assert.equal(cfg.sandboxInstitutionID, 'ins_109508');
});

// ---- Environment whitelist -----------------------------------------

test('rejects unsupported PLAID_ENV with UNSUPPORTED_ENV', () => {
  assert.throws(
    () => parseConfig({ ...baselineSandboxEnv, PLAID_ENV: 'development' }),
    (err) => err.code === 'UNSUPPORTED_ENV'
  );
});

test('SUPPORTED_ENVS is exactly sandbox + production', () => {
  assert.deepEqual([...SUPPORTED_ENVS].sort(), ['production', 'sandbox']);
});

// ---- Production opt-in ---------------------------------------------

test('production without PLAID_LIVE_DATA_EVALUATION=1 throws LIVE_DATA_NOT_OPTED_IN', () => {
  const env = { ...baselineProductionEnv };
  delete env.PLAID_LIVE_DATA_EVALUATION;
  assert.throws(
    () => parseConfig(env),
    (err) => err.code === 'LIVE_DATA_NOT_OPTED_IN'
  );
});

test('production with PLAID_LIVE_DATA_EVALUATION!=1 still throws', () => {
  const env = { ...baselineProductionEnv, PLAID_LIVE_DATA_EVALUATION: 'true' };
  assert.throws(
    () => parseConfig(env),
    (err) => err.code === 'LIVE_DATA_NOT_OPTED_IN'
  );
});

test('production with PLAID_LIVE_DATA_EVALUATION=1 + redirect parses', () => {
  const cfg = parseConfig(baselineProductionEnv);
  assert.equal(cfg.plaidEnv, 'production');
  assert.equal(cfg.isLiveDataEvaluation, true);
  assert.equal(
    cfg.redirectURI,
    'https://arieltyson.github.io/nomadfi-privacy/plaid-oauth'
  );
});

// ---- Production redirect URI ---------------------------------------

test('production without PLAID_REDIRECT_URI throws MISSING_REDIRECT_URI_FOR_PRODUCTION', () => {
  const env = { ...baselineProductionEnv };
  delete env.PLAID_REDIRECT_URI;
  assert.throws(
    () => parseConfig(env),
    (err) => err.code === 'MISSING_REDIRECT_URI_FOR_PRODUCTION'
  );
});

test('sandbox without PLAID_REDIRECT_URI parses (redirect optional)', () => {
  const env = { ...baselineSandboxEnv };
  delete env.PLAID_REDIRECT_URI;
  const cfg = parseConfig(env);
  assert.equal(cfg.redirectURI, null);
  assert.equal(cfg.plaidEnv, 'sandbox');
});

// ---- Plaid credentials ---------------------------------------------

test('missing PLAID_CLIENT_ID throws MISSING_PLAID_CREDENTIALS', () => {
  assert.throws(
    () => parseConfig({ PLAID_SECRET: 'x' }),
    (err) => err.code === 'MISSING_PLAID_CREDENTIALS'
  );
});

test('missing PLAID_SECRET throws MISSING_PLAID_CREDENTIALS', () => {
  assert.throws(
    () => parseConfig({ PLAID_CLIENT_ID: 'x' }),
    (err) => err.code === 'MISSING_PLAID_CREDENTIALS'
  );
});

// ---- LAN-mode shared secret ----------------------------------------

test('LAN bind host without shared secret throws LAN_MODE_MISSING_SECRET', () => {
  assert.throws(
    () =>
      parseConfig({
        ...baselineSandboxEnv,
        PLAID_BROKER_BIND_HOST: '192.168.1.42',
      }),
    (err) => err.code === 'LAN_MODE_MISSING_SECRET'
  );
});

test('LAN bind host with too-short shared secret throws', () => {
  assert.throws(
    () =>
      parseConfig({
        ...baselineSandboxEnv,
        PLAID_BROKER_BIND_HOST: '192.168.1.42',
        PLAID_BROKER_SHARED_SECRET: 'short',
      }),
    (err) => err.code === 'LAN_MODE_MISSING_SECRET'
  );
});

test('LAN bind host with valid shared secret parses + flips loopback flag', () => {
  const cfg = parseConfig({
    ...baselineSandboxEnv,
    PLAID_BROKER_BIND_HOST: '192.168.1.42',
    PLAID_BROKER_SHARED_SECRET: 'a'.repeat(32),
  });
  assert.equal(cfg.isLoopbackMode, false);
  assert.equal(cfg.bindHost, '192.168.1.42');
  assert.equal(cfg.sharedSecret.length, 32);
});

test('::1 and localhost are treated as loopback', () => {
  const ipv6 = parseConfig({
    ...baselineSandboxEnv,
    PLAID_BROKER_BIND_HOST: '::1',
  });
  assert.equal(ipv6.isLoopbackMode, true);

  const localhost = parseConfig({
    ...baselineSandboxEnv,
    PLAID_BROKER_BIND_HOST: 'localhost',
  });
  assert.equal(localhost.isLoopbackMode, true);
});

// ---- Plaid enum-list parser ----------------------------------------

test('parsePlaidEnumList accepts mixed casing and unknown tokens drop', () => {
  const enumObject = { US: 'US', CA: 'CA' };
  assert.deepEqual(parsePlaidEnumList('us, CA, JP', enumObject), ['US', 'CA']);
});

test('parsePlaidEnumList handles whitespace + empty tokens', () => {
  const enumObject = { transactions: 'transactions', auth: 'auth' };
  assert.deepEqual(
    parsePlaidEnumList('  transactions , , auth ', enumObject),
    ['transactions', 'auth']
  );
});
