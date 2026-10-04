# Connection messaging — October 4, 2026

Mutual friendship connections unlock a private text conversation. Existing reflection chat, AI memory, invitations, and user data remain separate. Inspired by Instagram's conversation pinning and replies; no Instagram account integration or cross-app messaging.

## Experience
- Inbox: newest activity, last-message preview, unread count, personal pinning.
- Text bubbles, timestamps, quoted replies, sent confirmation, optional seen status.
- Read receipts default off per conversation; only that person's opt-in reveals their read position. Turning off hides receipts again. Inbox unread counts work independently.
- Latest 30 messages with earlier history, at most 50 per API page. Stable per-conversation sequence handles identical timestamps.
- Active conversation refreshes every five seconds. No background push, typing indicators, media messages, or end-to-end encryption in this release.
- A failed send keeps the same request UUID for retry while the screen remains open. A successful response means the transaction committed. No durable offline outbox; closing the chat can lose an unconfirmed draft.
- Only both approved adult participants can access messages. Block, end connection, Connect-profile deletion and account deletion revoke access and remove relevant active records.
- Direct messages are not sent to OpenAI or saved to AI memory.

## Storage and operation
Existing single-instance SQLite on Render's persistent disk is retained. WAL, FULL synchronous commits, 15-second lock timeout, foreign keys, atomic migration, unique sequence indexes and idempotency checks protect delivery. This is a single-writer deployment, not a horizontally scalable cluster. Do not run multiple replicas against local disks. Before scaling, migrate to managed PostgreSQL and validate delivery/authorization again.

Tables: dating_matches, dating_messages (UUID, match, sender, text, timestamp, sequence, reply target), dating_chat_state (participant, read position, pin, receipt preference). User identifiers and messages stay private. Current cap: 20,000 messages per conversation, 1,000 characters per message, rate limits enforced. Inbox returns the first 100 conversations, pins before recent activity.

### Backup / restore
The operator can run `python -m omni_memory.backup SOURCE NEW_PRIVATE_DESTINATION`. It uses SQLite's backup API so uncheckpointed WAL content is included, refuses overwrite, restricts the file to owner access and checks integrity. A raw copy of the main DB file is unsafe while WAL is active.

This change does not configure scheduled backups or new paid storage. Before public enablement, the operator must schedule protected backups, choose retention compatible with the published deletion policy, and test restore in an isolated environment. Stop the service before a production restore; preserve the current DB and its sidecars, restore the verified snapshot with owner-only permissions, and remove sidecars only for the replaced database. Never restore over a running service or upload backups to GitHub. Reapply deletions made after a snapshot before reconnecting restored data.

## Validation / release
Synthetic tests cover simultaneous duplicate retries, history pagination, monotonic read cursors, receipt privacy, quoted replies, unauthorized access, account/profile cleanup, legacy schema migration, restart durability and WAL-aware snapshot restore. Native tests cover stable retry UUIDs, pagination merging and revoked access. Local demo uses fictional adults only.

Production discovery and the release entry remain gated until moderation ownership, current App Store privacy/age declarations and final device acceptance are complete. Build 8 predates this change and must not be submitted as containing it.
