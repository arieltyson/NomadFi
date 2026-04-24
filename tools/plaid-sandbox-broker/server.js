// server.js
// Local-only Plaid *sandbox* broker for NomadFi's Phase 5D bounded
// sandbox proof. Not deployed. Not shipped. Holds Plaid client_id /
// secret in an untracked `.env` file so nothing Plaid-shaped ever
// touches the iOS app or the repo.
//
// Endpoints exposed to the NomadFi iOS app:
//   POST /link/token/create
//   POST /item/public_token/exchange
//   POST /sandbox/item/create
//   POST /accounts/get         { item_id }
//   POST /transactions/sync    { item_id, cursor? }
//
// Endpoints intentionally NOT exposed to the app:
//   - anything that reveals the access_token to the client.
//   - anything that talks to production or development Plaid
//     environments.
//
// Source references (Plaid's own primary docs):
//   https://plaid.com/docs/api/link/
//   https://plaid.com/docs/api/items/
//   https://plaid.com/docs/api/products/transactions/
//   https://plaid.com/docs/sandbox/

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

// ---- Config ---------------------------------------------------------

const port = Number(process.env.PORT) || 8787;
const envName = (process.env.PLAID_ENV || 'sandbox').toLowerCase();
if (envName !== 'sandbox') {
  console.error(
    '[plaid-sandbox-broker] refusing to start — PLAID_ENV must be "sandbox"'
  );
  process.exit(1);
}
if (!process.env.PLAID_CLIENT_ID || !process.env.PLAID_SECRET) {
  console.error(
    '[plaid-sandbox-broker] PLAID_CLIENT_ID and PLAID_SECRET are required'
  );
  process.exit(1);
}

const countryCodes = (process.env.PLAID_COUNTRY_CODES || 'US')
  .split(',')
  .map((s) => s.trim().toUpperCase())
  .filter(Boolean)
  .map((code) => CountryCode[code])
  .filter(Boolean);

const products = (process.env.PLAID_PRODUCTS || 'transactions')
  .split(',')
  .map((s) => s.trim().toLowerCase())
  .filter(Boolean)
  .map((name) => Products[name])
  .filter(Boolean);

const sandboxInstitutionID = process.env.PLAID_SANDBOX_INSTITUTION_ID || 'ins_109508';
const redirectURI = (process.env.PLAID_REDIRECT_URI || '').trim() || null;

const plaid = new PlaidApi(
  new Configuration({
    basePath: PlaidEnvironments.sandbox,
    baseOptions: {
      headers: {
        'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
        'PLAID-SECRET': process.env.PLAID_SECRET,
      },
    },
  })
);

// ---- In-memory item store -------------------------------------------
//
// Each entry maps the opaque item handle the broker returns to the
// iOS app onto the real Plaid access_token. Restart the broker and
// you lose this state — acceptable for a sandbox proof. Production
// would persist this, but production is deliberately out of scope.

const itemStore = new Map(); // itemHandle -> { accessToken, institutionName }

// ---- App ------------------------------------------------------------

const app = express();
app.use(express.json({ limit: '64kb' }));
// Bind to localhost only. Never expose this broker on a public
// interface: it carries Plaid sandbox credentials.
app.set('trust proxy', false);

app.get('/health', (_req, res) => {
  res.json({ ok: true, env: envName });
});

app.post('/link/token/create', async (_req, res) => {
  try {
    const payload = {
      user: { client_user_id: 'nomadfi-sandbox-user' },
      client_name: 'NomadFi Sandbox',
      products,
      country_codes: countryCodes,
      language: 'en',
    };
    // Plaid requires an HTTPS redirect_uri for OAuth-capable
    // institutions on iOS. The URL must match the app's associated
    // domains entitlement exactly (NomadFi uses `applinks:arieltyson.github.io`).
    // Omitted for non-OAuth sandbox flows.
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
    console.error('[plaid-sandbox-broker] plaid error', plaidError);
    res.status(502).json({
      error_code: plaidError.error_code || 'PLAID_ERROR',
      error_type: plaidError.error_type || null,
      error_message: plaidError.error_message || null,
    });
    return;
  }
  console.error('[plaid-sandbox-broker] unexpected error', err);
  res.status(500).json({
    error_code: 'BROKER_ERROR',
    error_message: err && err.message ? err.message : null,
  });
}

app.listen(port, '127.0.0.1', () => {
  console.log(
    `[plaid-sandbox-broker] listening on http://127.0.0.1:${port} (env=${envName})`
  );
});
