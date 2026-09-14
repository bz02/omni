# Account memory sync

Omni can keep a separate, explicitly synced copy of each signed-in account's saved memories and conversation history. Sync is a manual action in this version. It does not import guest data, include the journal, or turn on online conversations on another device.

This is implemented infrastructure, not proof of a deployed production service. The app still requires configured account and subscription verification, a reachable HTTPS service, a persistent private database and published privacy disclosures before real users can use cloud sync.

## User behavior

1. Sign in to the same Omni account on each iPhone. Each account has its own local memory file.
2. Open account memory and allow the current sync session.
3. Choose **Sync now**. The app first reads the cloud revision.
4. A previously synced, unchanged copy can be downloaded; a local edit can be uploaded only against the known cloud revision.
5. If both copies changed, neither is silently replaced. Export either copy, then explicitly choose which copy to keep. There is no automatic merge.
6. A deleted cloud copy has a revision tombstone. A device with older records must review the deletion instead of silently uploading them again.

Temporary conversations never enter the local archive and therefore never enter this snapshot. Turning off history stops future history saves; it does not delete previous saved conversations. Memory/history settings travel with the snapshot; permission to send messages to OpenAI stays on each device.

## Data and ownership

Cloud snapshots contain native `MemoryArchive` version 1 with ISO 8601 timestamps:

- Account UUID, memory/history settings, saved memories, conversations and messages.
- Memory IDs, kind, text, creation/update times and explicit user confirmation.
- Optional original conversation/message IDs and assistant context citations.

The server rejects snapshots whose `ownerID` differs from the authenticated account UUID. Every database query includes that authenticated subject. A request cannot choose another owner through the body. Sources must reference an existing user message in the same snapshot, and citations must reference existing memory IDs. Duplicate record/message IDs, unsupported schema versions, unconfirmed memories, numeric or timezone-free dates, unknown fields and device-only consent fields are rejected.

The snapshot excludes `allowOnlineConversations` and `localSync` bookkeeping. It does not contain guest memory, the separate journal, Apple credentials, access tokens, contacts or birth charts. Saved conversation text remains conversation text: deleting a memory does not rewrite earlier messages that already mention that fact. The user can delete those conversations separately.

Limits are 1,900,000 encoded bytes per archive, 2,000 memories, 2,000 conversations, 2,000 messages per conversation, 1,000 characters per memory and 16,000 characters per message. HTTP request bodies are additionally capped at 2 MiB. This is intentionally a small beta snapshot store, not unlimited history storage.

## HTTP contract

All routes require the managed account bearer session. The route integration must authenticate and check account deletion/revocation before entering `SnapshotService`. The snapshot service uses the existing server entitlement rather than trusting a client-provided paid flag.

| Method and path | Request | Result |
| --- | --- | --- |
| `GET /v1/memory/snapshot` | None | `{revision, archive}`; a never-synced account begins at revision 0 with `archive: null` |
| `PUT /v1/memory/snapshot` | `{expected_revision, archive}` | New `{revision, archive}` |
| `DELETE /v1/memory/snapshot` | `{expected_revision}` | Incremented `{revision, archive: null}` |

The comparison and write happen in one SQLite transaction. Two writers against the same revision cannot both succeed. A stale write or delete returns HTTP 409. The client never automatically retries a failed write with a freshly read revision, since that would silently replace another device's work.

Paying users may append new records and messages. After expiry, users can still download, export, correct or delete existing content. A snapshot update from an expired subscriber cannot add a new memory ID, conversation ID or message ID, move a message into a new conversation, or enable memory when it was previously off. These checks also apply after a tombstone, when there are no existing content IDs to edit.

The `native_snapshots` table retains a revision and nullable archive per account. `SnapshotService.erase_in_db(db, subject)` clears content and increments its revision inside the caller's transaction. `erase_all_data(subject)` atomically erases legacy memory/conversations and this snapshot. Permanent account deletion calls `purge_account(db, subject)` or removes that table row in the same transaction that revokes all sessions and deletes the identity. Session revocation is essential: removing the row alone would reset its revision.

Static `/memory/snapshot` routes must be registered before `/memory/{identifier}` so DELETE is routed correctly.

## Native contract

`MemoryStore.forAccount(accountID)` opens only the account UUID's own file. `removeAccountCache(accountID)` deletes only that cache. The separate guest archive is preserved. A signed-out account's cache is inaccessible through the signed-out UI; deletion of the complete account also removes its local cache.

The store persists `localSync.cloudRevision` and a SHA-256 hash of the last acknowledged cloud payload in the same protected atomic file as its archive. `hasUnsyncedChanges` therefore remains accurate after restarting the app. The hash excludes online consent, so changing permission to contact OpenAI does not create a cloud content change. No account data is sent by the store initializer.

- `snapshotData()` returns only cloud-eligible JSON.
- `applyCloudSnapshot(snapshot, expectedLocalRevision:)` verifies ownership, sources and citations, then replaces local data only if it has not changed since the request started. It preserves local online consent and records the downloaded baseline atomically.
- `recordSuccessfulUpload(remoteRevision:expectedLocalRevision:)` records a baseline only when no newer local edit occurred during upload. A late acknowledgement does not falsely mark that newer edit as synced.
- Older remote revisions are rejected. A local reset stays dirty against its previous cloud baseline until the user explicitly syncs the deletion or chooses another copy.

`MemorySyncClient(endpoint:tokenProvider:)` accepts the service's base URL and an asynchronous provider of fresh access tokens. `pull`, `push` and `delete` each require explicit consent. It uses an ephemeral URLSession, no cookies or disk cache, bounded responses, timeouts, and rejects redirects. Release builds require HTTPS; DEBUG supports loopback HTTP for development. The client never puts provider or signing secrets in the app.

## Verification

No real accounts, Apple purchases, deployed server or model calls were used in these tests.

- 21 server snapshot tests passed, including actual concurrent compare-and-swap writes, cross-owner isolation, expired access, strict sources/citations, deletion tombstones, size limits and cleanup hooks.
- Eight native sync tests passed in an independent macOS Swift Testing package, alongside the 12 existing memory store tests. They cover separate account files, persistent dirty baselines, source-preserving downloads, device consent, stale operations, tombstones, fresh tokens, request payloads and surfaced conflicts.
- The native core passed Swift type checking. Integrated iOS unit validation also passed: 57 tests in `build/AccountMemoryUnitTests.xcresult`, including these eight sync tests. UI and unsigned Release evidence is recorded in [BUILD_STATUS.md](BUILD_STATUS.md).

The server snapshot sits in the existing private SQLite database. Deployment must provide persistent storage, restricted file permissions, HTTPS, suitable encrypted storage/backups and a defined retention policy. This implementation does not claim end-to-end encryption or encrypted application-level database contents. Provider chat retention and cloud snapshot retention are separate data flows and must both be disclosed.
