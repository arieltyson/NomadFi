# Plaid Validation Evidence — Artifact Template

Companion to
[`PlaidRealDeviceValidation.md`](./PlaidRealDeviceValidation.md).
Describes exactly what the DEBUG-only validation recorder produces,
what it deliberately excludes, and how to hand the artifact back for
decisioning on Phase 5D criterion 5.

---

## 0. Where the export comes from

- **NomadFi (DEBUG build only)** → Settings → Financial Setup →
  Financial Connections → **Plaid sandbox developer harness** →
  **Validation recorder** section.
- The recorder is shared between the harness page and the main
  Financial Connections page, so every broker / Link / sync event
  lands in the same session no matter which page is on screen when
  it fires.
- Exports happen after the developer taps **End session** and
  picks a result (`pass`, `fail`, or `inconclusive`). The recorder
  then exposes two formats through the iOS share sheet:
  - **Markdown** (human-readable, includes a criterion-5
    self-assessment block).
  - **JSON** (deterministic, sorted keys, ISO-8601 timestamps).
- Production builds do not compile the recorder or the UI. The
  entire diagnostics layer is wrapped in `#if DEBUG`.

---

## 1. What the artifact captures

Each event is one row with a kind + a narrow string-to-string
`details` map. The kinds are an enumeration pinned in code:

| Kind | Captured details |
|---|---|
| `session_started` | `schema_version` |
| `broker_config_saved` | `broker_url` (presence only), `broker_secret_configured` |
| `broker_config_cleared` | — |
| `broker_health_checked` | `reachable`, `env`, `requires_secret`, `redirect_uri_configured`, `failure_reason` (redacted) |
| `link_launch_requested` | — |
| `link_phase_changed` | `from`, `to` |
| `universal_link_observed` | `host` (the configured associated domain only) |
| `public_token_exchanged` | `success`, `failure_reason` (redacted) |
| `item_handle_persisted` | `masked_item_handle` |
| `item_handle_cleared` | — |
| `sync_started` | `window_start`, `window_end` |
| `sync_finished` | `account_snapshots`, `transaction_snapshots`, `degraded_gracefully`, `provider_<logKey>` |
| `reconciliation_finished` | full counts from `FinancialDataReconciliationResult` |
| `institution_observed` | `display_name_included` (plus `display_name` if the developer opts in) |
| `result_marked` | `result` |
| `note` | `length`, `preview` (first 140 chars) |
| `session_ended` | `result`, `note_length` |

Events carry an ISO-8601 timestamp and a UUID. The session wrapper
adds `id`, `started_at`, `ended_at`, `result`, and `note`.

---

## 2. What the artifact deliberately excludes

The recorder rejects or masks these values by construction — the
detail maps listed above are the **only** paths by which data enters
the export:

- Plaid `public_token` / `access_token` / `link_token`.
- Plaid `client_id` / `secret`.
- The full broker URL (the exported value is `configured` or
  `missing`). Broker hostnames and LAN IPs never appear.
- The broker shared secret (the export stores a boolean
  `broker_secret_configured`, never the secret itself).
- Plaid OAuth redirect URL query strings. The recorder logs only the
  universal-link host, which is NomadFi's own GitHub Pages origin.
- Raw Plaid item handles — `PlaidValidationRedactor.maskedItemHandle`
  keeps the `itm_` prefix + last four characters, everything else
  is `****`.
- Error messages pass through `redactedError`, which strips URLs,
  IPv4 `host:port` patterns, and long hex tokens.
- Institution display names are off by default. The developer has to
  toggle **Include institution name in export** on the harness page
  before starting the session. The toggle is preserved as
  `display_name_included` in every `institution_observed` event so
  the exported artifact is self-describing.

---

## 3. Markdown shape

The Markdown export follows this skeleton exactly (schema version
1). Claude can parse it as plain Markdown without a special parser:

```markdown
# NomadFi Plaid Sandbox Validation Report

- **Session ID:** 2C3D…
- **Started:** 2026-04-24T12:00:00Z
- **Ended:** 2026-04-24T12:12:30Z
- **Duration:** 12m 30s
- **Result:** pass
- **Note:** Smooth OAuth return.
- **App version:** 1.0 (1)
- **Schema version:** 1

## Events

| # | Time | Event | Details |
|---|------|-------|---------|
| 1 | 2026-04-24T12:00:00Z | session_started | schema_version=1 |
| 2 | 2026-04-24T12:00:30Z | broker_health_checked | env=sandbox, reachable=true, redirect_uri_configured=true, requires_secret=true |
| … | … | … | … |

## Criterion 5 self-assessment

- Broker reachable: yes
- Plaid Link launched: yes
- Universal-link return observed: yes
- Public-token exchanged: yes
- Item handle persisted: yes
- Reconciliation counts: 1 created, 5 inserted transactions
- Institution observed: Royal Bank of Canada (vendor-reported by Plaid Link)
- Result: pass

> Generated at 2026-04-24T12:12:31Z
```

When pasting back, prefer the whole Markdown — the criterion-5 block
is enough to decide pass/fail/inconclusive by itself, and the event
table carries the supporting timeline.

---

## 4. JSON shape

The JSON export uses sorted keys + ISO-8601 timestamps so diffs are
deterministic across runs. A minimal example (abridged for brevity):

```json
{
  "app_version": "1.0 (1)",
  "generated_at": "2026-04-24T12:12:31Z",
  "schema_version": 1,
  "session": {
    "ended_at": "2026-04-24T12:12:30Z",
    "events": [
      {
        "details": { "schema_version": "1" },
        "id": "…",
        "kind": "session_started",
        "timestamp": "2026-04-24T12:00:00Z"
      },
      {
        "details": {
          "env": "sandbox",
          "reachable": "true",
          "redirect_uri_configured": "true",
          "requires_secret": "true"
        },
        "id": "…",
        "kind": "broker_health_checked",
        "timestamp": "2026-04-24T12:00:30Z"
      }
    ],
    "id": "…",
    "note": "Smooth OAuth return.",
    "result": "pass",
    "started_at": "2026-04-24T12:00:00Z"
  }
}
```

---

## 5. Pass / fail / inconclusive criteria

The developer picks the result manually at **End session** time.
Claude (or any reviewer) should consider these signals:

### 5.1 Pass

All of:

- `broker_health_checked` with `reachable=true`.
- `link_launch_requested` present.
- `public_token_exchanged` with `success=true`.
- `item_handle_persisted` present (with a masked handle).
- `reconciliation_finished` with `created_accounts >= 1` OR
  `matched_durable >= 1` AND `unresolved_ambiguous_snapshots == 0`.
- `universal_link_observed` present **if** the institution required
  OAuth (unknown from the artifact alone; cross-reference the note
  or the developer's `session.note`).

### 5.2 Fail

Any of:

- `broker_health_checked` with `reachable=false`.
- `public_token_exchanged` with `success=false`.
- `reconciliation_finished` with `unresolved_ambiguous_snapshots > 0`
  (means the reconciler saw multiple candidate matches and refused
  — a data-model bug, not a pass).
- `link_phase_changed` ending in `to=failed`.

### 5.3 Inconclusive

Anything that doesn't clearly meet pass or fail. Common cases:

- Link reached `presenting_link` but neither `completed` nor `failed`
  was observed (user backgrounded the app during the bank's OAuth
  flow and Link's handler timed out).
- `item_handle_persisted` present but no `sync_finished` / no
  `reconciliation_finished` — user linked but didn't run Sync Now
  before exporting.

---

## 6. Handing the artifact back for review

1. Finish the validation run on the device.
2. Tap **End session**, pick a tentative result, optionally add a
   one-line note.
3. Tap **Export as Markdown**. iOS's share sheet opens.
4. Paste the Markdown into the next Claude turn.
5. Ask Claude to confirm the pass/fail assessment against §5 and to
   propose the next Phase 5 roadmap step.

Do not paste the JSON by default — it's larger and equivalent in
content. JSON is the canonical machine format; Markdown is faster
for review.

---

## 7. What this artifact does **not** decide

- Whether Plaid is the right *long-term* provider for NomadFi. That's
  the bakeoff memo's job, not this artifact.
- Cost modelling. No pricing information is captured here.
- Coverage depth. One successful Canadian FI sync resolves
  criterion 5 for that one FI, not for all of Plaid's marketed
  Canadian coverage.
- Whether NomadFi should proceed to Phase 5E. That's a product
  decision — the artifact is *evidence*, not a decision.

---

## 8. Primary sources used when designing this template

- Apple — Universal Links:
  https://developer.apple.com/library/archive/documentation/General/Conceptual/AppSearch/UniversalLinks.html
- Apple — Preventing Insecure Network Connections:
  https://developer.apple.com/documentation/security/preventing-insecure-network-connections
- Plaid — Link iOS SDK:
  https://plaid.com/docs/link/ios/
- Plaid — Link OAuth:
  https://plaid.com/docs/link/oauth/
- Plaid — Sandbox:
  https://plaid.com/docs/sandbox/
- Plaid — Link API:
  https://plaid.com/docs/api/link/
