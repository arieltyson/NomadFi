'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const os = require('node:os');

function run(overrides = {}) {
  return spawnSync(process.execPath, [path.join(__dirname, 'preflight.js')], {
    cwd: os.tmpdir(),
    encoding: 'utf8',
    env: {
      PATH: process.env.PATH,
      DOTENV_CONFIG_PATH: path.join(os.tmpdir(), 'nomadfi-no-env-file'),
      PLAID_CLIENT_ID: 'test-client-must-not-appear',
      PLAID_SECRET: 'test-secret-must-not-appear',
      PLAID_ENV: 'production',
      PLAID_LIVE_DATA_EVALUATION: '1',
      PLAID_COUNTRY_CODES: 'CA',
      PLAID_PRODUCTS: 'transactions',
      PLAID_REDIRECT_URI: '',
      PLAID_BROKER_BIND_HOST: '0.0.0.0',
      PLAID_BROKER_SHARED_SECRET: 'test-broker-secret-must-not-appear',
      ...overrides,
    },
  });
}

test('production preflight validates Canada without claiming account access or leaking credentials', () => {
  const result = run();
  assert.equal(result.status, 0, result.stderr);
  const report = JSON.parse(result.stdout);
  assert.equal(report.environment, 'production');
  assert.equal(report.canadian_evaluation_scope, true);
  assert.equal(report.redirect_configured, false);
  assert.match(report.production_access, /not checked/);
  assert.doesNotMatch(result.stdout + result.stderr, /must-not-appear/);
});

test('preflight rejects bad products and country codes against the installed Plaid SDK', () => {
  for (const override of [
    { PLAID_PRODUCTS: 'transactions,balance' },
    { PLAID_PRODUCTS: 'transactions,typo' },
    { PLAID_PRODUCTS: '' },
    { PLAID_COUNTRY_CODES: '', PLAID_REDIRECT_URI: 'https://example.com/oauth' },
    { PLAID_COUNTRY_CODES: 'CA,TYPO', PLAID_REDIRECT_URI: 'https://example.com/oauth' },
  ]) {
    const result = run(override);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /INVALID_LINK_PRODUCT|INVALID_PLAID_ENUM_LIST/);
    assert.doesNotMatch(result.stdout + result.stderr, /must-not-appear/);
  }
});
