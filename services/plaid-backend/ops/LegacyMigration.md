# Controlled legacy Item transfer

This implementation supports the preferred path where the existing Plaid Item
and its provider IDs are preserved. It has not been run against the live CIBC
Item. The existing broker has no token-export endpoint; a secured recovery of
its token is still required before this transfer can be used. Do not restart
the broker, print its memory, place tokens in shell arguments, or introduce an
unauthenticated export route to obtain one.

After H0 acceptance, use a restricted operator session in the backend environment
to run `node scripts/import-legacy-item.js`. Feed a private JSON object on stdin
with `user_id`, `environment`, `access_token`, `expected_item_id` and the complete
`expected_account_ids` array. All normal service configuration and KMS requirements
apply. The user must already have signed in as an allowlisted verified Apple
subject. Never commit this input or include it in command history or build logs.

The default preview calls read-only Plaid endpoints to verify the exact Item and
account set. It does not store credentials or alter the webhook. An explicit
`commit: true` input persists encrypted credentials and the connection first,
then changes the webhook and queues bootstrap sync. Retrying a webhook failure
uses the same connection. The tool never revokes the original Item.

Before switching the phone, verify a current private device backup and its
restore path. In Hosted Connections, choose **Review migration of existing bank
records**. The review requires every legacy account's provider ID and currency
to match exactly one hosted account. It preserves persistent local accounts,
user annotations and receipt relationships, rewrites transaction identities
within their bank connection, and commits the mapping, ledger and checkpoint
together. Older local history absent from the hosted range remains on-device.
Actual provider removals use the same note/receipt archive as ordinary sync.

The review expires after 15 minutes, is scoped to the signed-in owner and service,
and is rejected if the local record set changes. The user verifies the backup
before applying. The old local Item handle is removed only after the commit;
stale local-provider reports cannot recreate legacy accounts once hosted
accounts exist. A failed acknowledgment can safely retry ordinary hosted sync.

If re-linking issued new provider IDs, this automatic review deliberately stops.
That path still needs a separately reviewed mapping and duplicate/history audit;
display-name or amount matching is not accepted as proof. Do not revoke a
superseded Item until the new connection, dashboard totals, notes and receipts
are verified. Restore the private backup before reverting to the local broker.

H5 still requires actual private migration evidence, each additional bank's
coverage/authorization, Mac-off synchronization, and at least seven days of
observations including an actual upstream update. Synthetic tests cannot close
those gates.
