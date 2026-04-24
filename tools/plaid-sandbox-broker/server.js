// server.js
// Local-only Plaid broker for NomadFi's Phase 5D + 5E preflight.
// Not deployed. Not shipped. Holds Plaid `client_id` / `secret` in
// an untracked `.env` file so nothing Plaid-shaped ever touches the
// iOS app or the repo.
//
// Two modes (full rules in `config.js`):
//
//   1. Sandbox (default).  PLAID_ENV=sandbox.
//      Backed by https://plaid.com/docs/sandbox/ — pre-defined test
//      institutions + test credentials. The `/sandbox/*` shortcut
//      endpoints are available.
//
//   2. Live-data evaluation.  PLAID_ENV=production AND
//      PLAID_LIVE_DATA_EVALUATION=1.
//      Backed by Plaid's production endpoint per
//      https://plaid.com/docs/api/. Requires Plaid Dashboard
//      production / Limited Production access for the developer's
//      account; requires PLAID_REDIRECT_URI; rejects every
//      `/sandbox/*` shortcut so behavior is unambiguous.
//
// Endpoints exposed to the NomadFi iOS app:
//   POST /link/token/create
//   POST /item/public_token/exchange
//   POST /sandbox/item/create        (sandbox only — 410 in production)
//   POST /accounts/get               { item_id }
//   POST /transactions/sync          { item_id, cursor? }
//
// The folder name `tools/plaid-sandbox-broker/` is historical; the
// broker now safely supports both modes. Folder rename intentionally
// avoided to keep diffs narrow.
//
// Source references (Plaid's own primary docs):
//   https://plaid.com/docs/api/link/
//   https://plaid.com/docs/api/items/
//   https://plaid.com/docs/api/products/transactions/
//   https://plaid.com/docs/sandbox/
//   https://plaid.com/docs/link/oauth/

'use strict';

const express = require('express');
const {
  Configuration,
  PlaidApi,
  PlaidEnvironments,
  Products,
  CountryCode,
} = require('plaid');
const crypto = require('crypto');
require('dotenv').config();

const {
  parseConfig,
  parsePlaidEnumList,
} = require('./config');

// ---- Config ---------------------------------------------------------

let config;
try {
  config = parseConfig(process.env);
} catch (err) {
  console.error(
    `[plaid-broker] refusing to start — ${err.code || 'CONFIG_ERROR'}: ${err.message}`
  );
  process.exit(1);
}

const {
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
} = config;

const countryCodes = parsePlaidEnumList(countryCodesRaw, CountryCode);
const products = parsePlaidEnumList(productsRaw, Products);

const plaidBasePath =
  isLiveDataEvaluation
    ? PlaidEnvironments.production
    : PlaidEnvironments.sandbox;

const plaid = new PlaidApi(
  new Configuration({
    basePath: plaidBasePath,
    baseOptions: {
      headers: {
        'PLAID-CLIENT-ID': clientID,
        'PLAID-SECRET': secret,
      },
    },
  })
);

// ---- In-memory item store -------------------------------------------
//
// Each entry maps the opaque item handle the broker returns to the
// iOS app onto the real Plaid access_token. Restart the broker and
// you lose this state — acceptable for a developer evaluation
// harness. Production-grade persistence is deliberately out of
// scope.

const itemStore = new Map(); // itemHandle -> { accessToken, plaidItemID }

// ---- App ------------------------------------------------------------

const app = express();
app.use(express.json({ limit: '64kb' }));
// Never trust X-Forwarded-* headers — the broker is only ever
// reachable directly (loopback or developer LAN). `trust proxy`
// would widen the attack surface.
app.set('trust proxy', false);

// In LAN mode, every request must carry the shared secret header.
// Loopback mode skips the check so CLI tools like `curl` + the
// broker's own `/health` probe stay frictionless on the dev
// machine. `/health` stays available in both modes because the iOS
// harness uses it to tell the developer "broker reachable" before
// anything Plaid-sensitive is attempted.
app.use((req, res, next) => {
  if (isLoopbackMode) return next();
  const supplied = req.get('x-nomadfi-broker-secret') || '';
  if (supplied !== sharedSecret) {
    res.status(401).json({ error_code: 'MISSING_OR_INVALID_SECRET' });
    return;
  }
  next();
});

app.get('/health', (_req, res) => {
  res.json({
    ok: true,
    env: plaidEnv,
    requires_secret: !isLoopbackMode,
    redirect_uri_configured: redirectURI !== null,
  });
});

app.post('/link/token/create', async (_req, res) => {
  try {
    const payload = {
      user: { client_user_id: 'nomadfi-evaluation-user' },
      client_name: 'NomadFi',
      products,
      country_codes: countryCodes,
      language: 'en',
    };
    // Plaid requires an HTTPS redirect_uri for OAuth-capable
    // institutions on iOS. The URL must match the app's associated
    // domains entitlement exactly (NomadFi uses
    // `applinks:arieltyson.github.io`). Required in production;
    // optional in sandbox (sandbox institutions do not exercise
    // OAuth).
    if (redirectURI) {
      payload.redirect_uri = redirectURI;
    }
    const response = await plaid.linkTokenCreate(payload);
    res.json({ link_token: response.data.link_token });
  } catch (err) {
    sendPlaidError(res, err);
  }
});

app.post('/item/public_token/exchange', async (req, res) => {
  const publicToken = req.body && req.body.public_token;
  if (typeof publicToken !== 'string' || publicToken.length === 0) {
    res.status(400).json({ error_code: 'MISSING_PUBLIC_TOKEN' });
    return;
  }
  try {
    const exchanged = await plaid.itemPublicTokenExchange({
      public_token: publicToken,
    });
    const accessToken = exchanged.data.access_token;
    const plaidItemID = exchanged.data.item_id;
    const itemHandle = 'itm_' + crypto.randomBytes(12).toString('hex');
    itemStore.set(itemHandle, { accessToken, plaidItemID });
    // Resolving the institution name is best-effort: we don't want a
    // network blip here to fail the whole link flow, and the app has
    // a calm fallback label.
    let institutionID = null;
    let institutionName = null;
    try {
      const item = await plaid.itemGet({ access_token: accessToken });
      institutionID = item.data.item.institution_id || null;
      if (institutionID) {
        const institution = await plaid.institutionsGetById({
          institution_id: institutionID,
          country_codes: countryCodes,
        });
        institutionName = institution.data.institution.name;
      }
    } catch (_) {
      institutionName = null;
    }
    res.json({
      item_id: itemHandle,
      institution_id: institutionID,
      institution_name: institutionName,
      plaid_item_id: plaidItemID,
    });
  } catch (err) {
    sendPlaidError(res, err);
  }
});

app.post('/sandbox/item/create', async (_req, res) => {
  if (isLiveDataEvaluation) {
    res.status(410).json({
      error_code: 'SANDBOX_ENDPOINT_DISABLED_IN_PRODUCTION',
      error_message:
        'The /sandbox/item/create shortcut is disabled when PLAID_ENV=production. ' +
        'Use the real Plaid Link flow against your target institution instead.',
    });
    return;
  }
  try {
    const created = await plaid.sandboxPublicTokenCreate({
      institution_id: sandboxInstitutionID,
      initial_products: products,
    });
    const publicToken = created.data.public_token;
    const exchanged = await plaid.itemPublicTokenExchange({
      public_token: publicToken,
    });
    const accessToken = exchanged.data.access_token;
    const itemID = exchanged.data.item_id;

    const itemHandle = 'itm_' + crypto.randomBytes(12).toString('hex');
    itemStore.set(itemHandle, { accessToken, plaidItemID: itemID });

    let institutionName = null;
    try {
      const institution = await plaid.institutionsGetById({
        institution_id: sandboxInstitutionID,
        country_codes: countryCodes,
      });
      institutionName = institution.data.institution.name;
    } catch (_) {
      // Non-fatal. The iOS side has a stable fallback label.
    }

    res.json({
      item_id: itemHandle,
      institution_id: sandboxInstitutionID,
      institution_name: institutionName,
    });
  } catch (err) {
    sendPlaidError(res, err);
  }
});

app.post('/accounts/get', async (req, res) => {
  const accessToken = resolveAccessToken(req, res);
  if (!accessToken) return;
  try {
    const response = await plaid.accountsGet({ access_token: accessToken });
    let institutionName = null;
    try {
      const item = response.data.item;
      if (item && item.institution_id) {
        const institution = await plaid.institutionsGetById({
          institution_id: item.institution_id,
          country_codes: countryCodes,
        });
        institutionName = institution.data.institution.name;
      }
    } catch (_) {
      institutionName = null;
    }
    res.json({
      accounts: response.data.accounts,
      institution_name: institutionName,
    });
  } catch (err) {
    sendPlaidError(res, err);
  }
});

app.post('/transactions/sync', async (req, res) => {
  const accessToken = resolveAccessToken(req, res);
  if (!accessToken) return;
  const cursor = typeof req.body.cursor === 'string' ? req.body.cursor : undefined;
  try {
    const payload = { access_token: accessToken };
    if (cursor) payload.cursor = cursor;
    const response = await plaid.transactionsSync(payload);
    res.json({
      added: response.data.added,
      modified: response.data.modified,
      removed: response.data.removed,
      next_cursor: response.data.next_cursor,
      has_more: response.data.has_more,
    });
  } catch (err) {
    sendPlaidError(res, err);
  }
});

// ---- Helpers --------------------------------------------------------

function resolveAccessToken(req, res) {
  const itemHandle = req.body && req.body.item_id;
  if (!itemHandle) {
    res.status(400).json({ error_code: 'MISSING_ITEM_ID' });
    return null;
  }
  const entry = itemStore.get(itemHandle);
  if (!entry) {
    res.status(404).json({ error_code: 'UNKNOWN_ITEM' });
    return null;
  }
  return entry.accessToken;
}

function sendPlaidError(res, err) {
  const plaidError = err && err.response && err.response.data;
  if (plaidError) {
    console.error('[plaid-broker] plaid error', plaidError);
    res.status(502).json({
      error_code: plaidError.error_code || 'PLAID_ERROR',
      error_type: plaidError.error_type || null,
      error_message: plaidError.error_message || null,
    });
    return;
  }
  console.error('[plaid-broker] unexpected error', err);
  res.status(500).json({
    error_code: 'BROKER_ERROR',
    error_message: err && err.message ? err.message : null,
  });
}

app.listen(port, bindHost, () => {
  console.log(
    `[plaid-broker] listening on http://${bindHost}:${port} ` +
      `(env=${plaidEnv}, ${isLoopbackMode ? 'loopback' : 'LAN + shared-secret required'})`
  );
  if (isLiveDataEvaluation) {
    console.warn(
      '[plaid-broker] LIVE-DATA EVALUATION MODE. Real Plaid production ' +
        'credentials are in use. /sandbox/* endpoints are disabled. ' +
        'Stop the broker (Ctrl-C) the moment evaluation is complete; ' +
        'never run this mode on an untrusted network.'
    );
  } else if (!isLoopbackMode) {
    console.log(
      '[plaid-broker] REMINDER: only run LAN mode during active ' +
        'real-device validation, on a trusted network, behind a firewall.'
    );
  }
});
