# Plaid Sandbox Broker

Local-only HTTP broker that holds Plaid **sandbox** credentials on
behalf of the NomadFi iOS app during the bounded Phase 5D sandbox
proof (see
[`docs/research/OpenFinanceProviderBakeoff.md`](../../docs/research/OpenFinanceProviderBakeoff.md)
and
[`docs/research/PlaidSandboxProof.md`](../../docs/research/PlaidSandboxProof.md)).

This process is **not** shipped. It is not deployed. It is run by a
developer on their own machine, reachable only on `127.0.0.1`.

## Why this exists

Plaid's `client_id` and `secret` are server-side credentials. Putting
them in an iOS app — even in the Keychain — would be a Plaid policy
violation and, more importantly, would leak every sandbox user's
consent scope to anyone with access to the binary. The broker keeps
the credentials out of the app entirely. The iOS side only ever sees:

- a broker base URL the developer sets in the Keychain (
  `com.nomadfi.plaidSandboxBrokerURL`);
- an opaque item handle (`itm_…`) the broker issues after it has
  exchanged Plaid's `public_token` for an `access_token`;
- a `/transactions/sync` cursor.

The real `access_token` never leaves the broker process.

## Setup

1. Install Node.js 20+ (the `engines` field pins the minimum).
2. From this directory:

   ```sh
   cp .env.example .env
   # Paste only SANDBOX credentials into .env.
   # PLAID_ENV=sandbox is enforced — the broker refuses to start
   # against development or production environments.
   npm install
   npm run start
   ```

3. Verify `curl http://127.0.0.1:8787/health` returns `{"ok":true,"env":"sandbox"}`.

## Configuring the iOS app

On a development device or simulator with the NomadFi debug build:

1. Open Settings → Financial Setup → Financial Connections. The
   Plaid sandbox row reads **Not enabled in this build** by default.
2. Store the broker URL in the Keychain (`com.nomadfi.plaidSandboxBrokerURL`).
   For local development this can be done through a debug helper in
   Xcode (breakpoint + `po` call to `PlaidSandboxConfiguration().setBrokerURL(…)`).
   Production builds do not and should not call this path.
3. Tap **Authorize** on the Plaid sandbox row. The provider will
   call `/sandbox/item/create` and persist the returned item handle.
4. Tap **Sync Now**. The provider calls `/accounts/get` and
   `/transactions/sync`, maps the responses through
   `PlaidSandboxSnapshotMapper`, and hands the provider-neutral
   snapshots to `FinancialDataReconciler`.

## Endpoints

| Method + path | Purpose |
|---|---|
| `GET  /health` | Liveness + active env |
| `POST /link/token/create` | Creates a Plaid `link_token`. When `PLAID_REDIRECT_URI` is set, the token requests the OAuth universal-link return path so OAuth-capable institutions can reopen NomadFi after the bank's consent. |
| `POST /item/public_token/exchange` | `{ public_token }` from a real Link success → Plaid `/item/public_token/exchange`; returns an opaque item handle and the resolved institution name where possible. |
| `POST /sandbox/item/create` | Plaid `/sandbox/public_token/create` → `/item/public_token/exchange`; returns an opaque item handle. Still available for sandbox-bypass tests. |
| `POST /accounts/get` | `{ item_id }` → Plaid `/accounts/get` + institution name |
| `POST /transactions/sync` | `{ item_id, cursor? }` → Plaid `/transactions/sync` diff |

## Reachability modes

The broker has two operating modes:

1. **Loopback (default).** `PLAID_BROKER_BIND_HOST=127.0.0.1`. Only
   processes on the same Mac can reach it. Simulator builds hit it
   through `http://127.0.0.1:8787`. No shared secret required.

2. **Developer LAN mode (Phase 5D real-device validation).** Set
   `PLAID_BROKER_BIND_HOST` to the Mac's LAN IP (e.g. `192.168.1.42`)
   or `0.0.0.0`. The broker then refuses to start unless
   `PLAID_BROKER_SHARED_SECRET` is set to a strong random value
   (>= 16 characters). Every request must carry an
   `X-NomadFi-Broker-Secret` header — the iOS app's developer
   harness (Settings → Financial Connections → Plaid sandbox
   developer harness) stores the matching secret in the Keychain.

LAN mode is intended *only* for the bounded Phase 5D real-device
validation runbook at
[`docs/research/PlaidRealDeviceValidation.md`](../../docs/research/PlaidRealDeviceValidation.md).
Exit LAN mode (stop the broker) when validation is done. Never run
LAN mode on an untrusted network.

## Security posture

- Default binds to `127.0.0.1` only.
- LAN mode is gated on a strong shared-secret enforced per request.
- Rejects startup unless `PLAID_ENV=sandbox`.
- Item handles are random 12-byte prefixes (`itm_…`) — they are not
  Plaid access_tokens.
- In-memory item store. A broker restart drops state; the iOS side
  re-runs the sandbox item flow to re-link.
- `.env` and `.state.json` are gitignored by this directory's
  `.gitignore`.

## Not in scope

- Production Plaid keys.
- Multi-user onboarding.
- Any persistent data plane beyond the sandbox lifetime.
- Any endpoint that returns the real Plaid `access_token` to the
  client.
- Any endpoint outside the minimum Phase 5D proof surface.
