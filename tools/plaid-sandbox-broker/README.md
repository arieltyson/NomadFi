# Plaid Broker (developer-only)

Local-only HTTP broker that holds Plaid credentials on behalf of the
NomadFi iOS app during developer evaluation runs. Two modes:

- **Sandbox** (default) — pairs with
  [`docs/research/PlaidSandboxProof.md`](../../docs/research/PlaidSandboxProof.md)
  and the Phase 5D real-device sandbox plumbing run.
- **Live-data evaluation** — pairs with
  [`docs/research/PlaidLimitedProductionReadiness.md`](../../docs/research/PlaidLimitedProductionReadiness.md)
  and the Phase 5D §8.3 live Canadian-FI run that resolves criterion 5.

This process is **not** shipped. It is not deployed. It runs on a
developer machine, reachable on `127.0.0.1` by default and only on
the LAN with a shared secret during active real-device evaluation.

The folder name (`plaid-sandbox-broker`) is historical — kept stable
to avoid pbxproj-adjacent churn now that the broker safely supports
both sandbox and live-data modes.

## Why this exists

Plaid's `client_id` and `secret` are server-side credentials per
[plaid.com/docs/api/](https://plaid.com/docs/api/) (vendor-reported).
Putting them in an iOS app — even in the Keychain — would be a Plaid
policy violation and would expose every user's consent scope to
anyone with access to the binary. The broker keeps the credentials
out of the app entirely. The iOS side only ever sees:

- a broker base URL the developer sets in the Keychain
  (`com.nomadfi.plaidSandboxBrokerURL`);
- an opaque item handle (`itm_…`) the broker issues after exchanging
  Plaid's `public_token` for an `access_token`;
- a `/transactions/sync` cursor.

The real `access_token` never leaves the broker process.

## Setup

1. Install Node.js 20+ (the `engines` field in `package.json` pins
   the minimum).
2. From this directory:

   ```sh
   # Only if .env does not exist yet:
   cp .env.example .env
   # Paste your Plaid credentials.
   # Sandbox mode (default): only sandbox keys are needed.
   # Live-data mode: see PlaidLimitedProductionReadiness.md first.
   npm ci
   npm run preflight
   npm run start
   ```

3. Verify with `curl http://127.0.0.1:8787/health`. Expected:

   ```json
   { "ok": true, "env": "sandbox", "requires_secret": false, "redirect_uri_configured": false }
   ```

## Operating modes

| Knob | Sandbox (default) | Live-data evaluation |
|---|---|---|
| `PLAID_ENV` | `sandbox` | `production` |
| `PLAID_LIVE_DATA_EVALUATION` | unset | `1` (must be set explicitly) |
| Plaid keys | sandbox secret | production secret (Trial, legacy Limited Production, or paid plan) |
| Plaid base URL | `https://sandbox.plaid.com` (vendor-reported) | `https://production.plaid.com` (vendor-reported) |
| `/sandbox/item/create` | available | **disabled (HTTP 410)** |
| `PLAID_REDIRECT_URI` | optional; needed for OAuth test institutions | optional for Canada-only; required by this broker for other country selections |
| Startup banner | quiet | loud LIVE-DATA reminder |

The broker refuses to start when:

- `PLAID_ENV` is anything other than `sandbox` or `production`;
- `PLAID_ENV=production` without `PLAID_LIVE_DATA_EVALUATION=1`
  (deliberate opt-in — a forgotten env edit cannot silently move the
  developer onto live data);
- `PLAID_ENV=production` with non-Canada-only coverage and no redirect;
- a configured redirect is not HTTPS or includes credentials/query/fragment;
- products include `balance`, or product/country lists are empty or invalid;
- `PLAID_BROKER_BIND_HOST` is anything other than loopback and
  `PLAID_BROKER_SHARED_SECRET` is shorter than 16 characters.

## Reachability

For the first Canadian run use `PLAID_COUNTRY_CODES=CA`,
`PLAID_PRODUCTS=transactions`, and an empty `PLAID_REDIRECT_URI`.
Accounts and cached balances come from `/accounts/get`; Auth is not
needed. Plaid's [Link API](https://plaid.com/docs/api/link/) does not
accept `balance` as an initialization product. Canadian institutions
currently do not use [OAuth](https://plaid.com/docs/link/oauth/).

`npm run preflight` checks local settings without contacting Plaid or
printing secrets. It does not prove production approval. Confirm the
team's plan, Canadian Transactions access, and remaining Item allowance
in the Dashboard before starting the live run. Trial plans have a
10-Item creation limit that removal does not replenish; see the
[preflight checklist](../../docs/research/PlaidLimitedProductionReadiness.md).

The broker has two reachability modes (orthogonal to sandbox /
live-data):

- **Loopback (default).** `PLAID_BROKER_BIND_HOST=127.0.0.1`. Only
  processes on the same Mac can reach it. Simulator builds hit it
  through `http://127.0.0.1:8787`. No shared secret required.
- **Developer LAN mode.** Set `PLAID_BROKER_BIND_HOST` to the Mac's
  LAN IP (e.g. `192.168.1.42`) or `0.0.0.0`. The broker then refuses
  to start without `PLAID_BROKER_SHARED_SECRET` (>= 16 chars). Every
  request must carry an `X-NomadFi-Broker-Secret` header — the iOS
  developer harness stores the matching secret in the Keychain.

LAN mode is intended only for active real-device evaluation. Stop
the broker when the run is done. Never run LAN mode on an untrusted
network.

## Endpoints

| Method + path | Purpose |
|---|---|
| `GET  /health` | Liveness + active env + secret + redirect-URI flags. |
| `POST /link/token/create` | Creates a Plaid `link_token`. Includes `redirect_uri` when configured. |
| `POST /item/public_token/exchange` | `{ public_token }` from a real Link success → Plaid `/item/public_token/exchange`; returns an opaque item handle and the resolved institution name where possible. |
| `POST /sandbox/item/create` | Sandbox-only shortcut: Plaid `/sandbox/public_token/create` → `/item/public_token/exchange`. **Disabled in production mode** (returns HTTP 410). |
| `POST /accounts/get` | `{ item_id }` → Plaid `/accounts/get` + institution name |
| `POST /transactions/sync` | `{ item_id, cursor? }` → Plaid `/transactions/sync` diff |

## Configuring the iOS app

The DEBUG-only Plaid sandbox developer harness in NomadFi
(Settings → Financial Setup → Financial Connections → Plaid sandbox
developer harness) is mode-agnostic — it shows whatever `env` the
broker reports through `/health`. Sandbox runs and live-data runs
use the **same harness UI**, distinguished by:

- the broker's reported `env` ("sandbox" vs "production");
- whether the developer toggles "Include institution name in
  export" before linking (recommended for live-data runs so the
  evidence artifact records the FI).

## Tests

```sh
npm test
```

Runs configuration, preflight CLI, and token-exchange recovery tests,
including concurrent exchange requests and replay after a lost response.

## Interrupted Link recovery

If bank login succeeds but the phone loses the broker connection, restore
the same network and use **Retry finishing link**. NomadFi retains the
temporary public token, original broker URL, and expiry in device-only
Keychain storage, allowing an app restart to resume within 30 minutes.
Successful exchange, expiry at the next launch/retry, or developer reset
clears the pending token. The prior item and sync cursor remain intact
until the new exchange succeeds.

The broker shares concurrent exchanges for a token and replays the same
item handle if the phone retries after losing the response. Only a hash
of the public token is used as the replay-cache key. Keep the broker
process alive: its item store and replay cache are still in memory.
A broker restart or an ambiguous failure between Plaid and the broker
is not recovered by this cache.

## Security posture

- Default binds to `127.0.0.1` only.
- LAN mode is gated on a strong shared-secret enforced per request.
- Live-data mode is gated on an explicit second flag
  (`PLAID_LIVE_DATA_EVALUATION=1`) so a forgotten env edit cannot
  push the developer onto production keys.
- Item handles are random 12-byte prefixes (`itm_…`) — never Plaid
  access_tokens.
- In-memory item store. A broker restart drops state.
- Stopping the broker does not revoke Items or stop subscription billing.
  Keep one session running through both sync checks and plan Dashboard
  cleanup before stopping. Persistent token storage is a rollout prerequisite.
- `.env` and `.state.json` are gitignored at the repo root and in
  this directory.

## Not in scope

- Production multi-user onboarding.
- Any persistent data plane beyond the developer evaluation lifetime.
- Any endpoint that returns the real Plaid `access_token` to the
  client.
- Webhooks, billing surfaces, or scale work — those belong to a
  later production rollout if/when the bakeoff memo's "go on Plaid"
  branch fires.
