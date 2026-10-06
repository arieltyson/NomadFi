# Hosted iOS pilot acceptance

The hosted client, V2 migration, local merge, and Settings flow are implemented.
They are disabled in ordinary builds until the deployment configuration below
is supplied. No real Apple sign-in, hosted bank Link, or migration was performed
by the implementation tests. The current CIBC broker and installed phone data
have not been changed.

## Enable after hosted H0 acceptance

- Configure the app's Sign in with Apple capability and provisioning profile.
  Inject its matching signing key/client/team metadata into the backend.
- Set `NomadFiHostedBackendURL` and `NomadFiPlaidRedirectURI` in the app's build
  Info.plist configuration. Both must be HTTPS. The OAuth return must match the
  Plaid Dashboard, associated domain entitlement and published AASA path.
- For a hosted Release build, include `HOSTED_BANKING` in
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS`. The LinkKit wrapper then compiles and
  the existing Release strip phase preserves its framework. Ordinary Release
  builds still omit the feature and strip LinkKit.
- Publish the reviewed hosted privacy policy/labels before accepting real bank
  records. The in-app consent describes server storage; it does not replace
  the full policy or Plaid's bank authorization.

## Device behavior

Settings → Financial Connections → Hosted bank connections offers native Apple
sign-in, per-connection status, additive Link, access repair, disconnect, and
download. The app downloads completed backend generations when foregrounded
and unlocked. The backend must run independently; iOS background execution is
not relied upon to maintain bank connectivity.

Pending Link and exchange state are kept in device-only Keychain storage.
OAuth continuation accepts only the configured HTTPS host/path. Recovery after
app termination restores the saved Link session before forwarding its return.
Real Chase OAuth/MFA and termination recovery still require physical-device
evidence. Cancellation does not remove existing connections.

Sign-out invalidates the app session and clears pending authorization state;
downloaded records remain in the protected local vault. The owner-only pilot
refuses to merge another hosted owner/endpoint into that vault. Switching owners
requires explicit data removal/migration; it does not silently reuse cached
bank data. In-app Delete All My Data requests hosted deletion first and retains
local records/credentials if that request cannot be confirmed. Backend deletion
then waits for upstream revocation and the documented backup retention period.

## Local data rules and evidence

- V1 is unchanged; V2 adds hosted delivery state through an explicit lightweight
  migration. A temporary on-disk V1 account survives the migration test.
- Downloaded pages are collected through a fixed publication revision; a save
  applies bank records and the device checkpoint together. Failed merges roll
  back. Acknowledgment follows that save, so replay remains safe.
- Identities are scoped to connection and provider. Unknown currency/account
  shapes stay in the ledger without invented projections. They must be shown
  as incomplete coverage by FiBot.
- Pending entries stay in the ledger and do not inflate posted spending.
  Modifications update the existing row and retain user notes/tax decisions.
- Removals archive user metadata and detach tax documents before deleting the
  transaction. Reintroduced identities restore annotations and receipt links.
- Accounts preserve country/reward/schedule fields. Removed/unknown hosted
  balances are excluded from net worth rather than using stale legacy values.
- Existing local Plaid records block hosted import until H5 provides a reviewed
  identity migration. There is no account-name fallback or automatic relink.

Simulator coverage currently includes secure client concurrency, refresh loss,
sign-out races, pending-exchange ownership, merge rollback/replay, receipt
preservation/restoration, legacy migration blocking, and V1 disk migration.
Production acceptance still requires host deployment, bank coverage checks,
the reviewed CIBC migration, Amex/Chase authorization, dashboard reconciliation,
and the seven-day observation recorded in `PlaidHostedSyncPlan.md`.
