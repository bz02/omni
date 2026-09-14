# Omni private memory backend

This is runnable, tested beta infrastructure for account-isolated memory and a configurable OpenAI Responses chat adapter. Apple login, revocable sessions, account-bound App Store verification and manual native snapshot sync are now integrated, but **not deployed or verified with real Apple credentials**. See [accounts](README_ACCOUNTS.md) and [sync](../docs/MEMORY_SYNC.md). No real model request or paid API call was made while implementing or testing it.

## Current native app integration

The iOS implementation owns its memory and conversations locally. It calls `/v1/chat` with `persist:false`, a short first-party session, and at most six selected memories (3,000 characters total)/eight recent turns. In this mode the server **does not read or save server memory or conversations**. The app opens a separate archive for the verified account UUID. The guest installation archive is distinct and is never automatically imported. A later explicit sync may upload saved conversations and memories even though sending a chat itself does not persist them on the server.

The native app uses the versioned `/v1/memory/snapshot` path for manual sync. The older per-record CRUD mode described below remains separate; it is not merged into native snapshots. Whole-account export includes both stores, whole-data erase clears both with a snapshot tombstone, and full account deletion clears both plus sessions and account identity.

The production iOS build must not accept operator-provided development sessions as a public login flow. The service refuses all requests, including loopback, without a configured strong signing secret and a valid session. Missing model configuration returns 503; it never fabricates an AI response.

## Local operation

Install `requirements-memory.txt` in the existing virtual environment, then run from `backend`:

```sh
python -m uvicorn omni_memory.app:create_app --factory --host 127.0.0.1 --port 8001 --no-access-log
```

Configure these variables privately in the service process. Never put their real values in source control, URLs, screenshots or logs:

| Variable | Meaning |
| --- | --- |
| `OMNI_MEMORY_DB` | Private SQLite path; default `./data/memory.sqlite3`. Keep it outside checked-in source and use encrypted storage in production. |
| `OMNI_MEMORY_SESSION_SECRET` | Cryptographically generated signing secret, at least 32 bytes. The implementation rejects short/obviously repetitive values. Generate a high-entropy value with a secret manager; do not invent a memorable password. |
| `OPENAI_API_KEY` | Server-side provider key, never shipped to iOS. |
| `OMNI_MEMORY_MODEL` | Explicit model identifier with Responses support. Optional memory suggestions require Structured Outputs support. No implicit default model or fallback model. |

Importing the factory does not create the default database. To mount in another FastAPI app:

```python
from omni_memory.app import create_router, MemoryService

app.include_router(create_router(MemoryService.from_env()))
```

The routes contain their own authentication, body bounds and sanitized validation behavior. They do not reuse the chart prototype's localhost exemption.

Both `create_app()` and `create_router()` default to managed accounts: access tokens need a live, unrevoked stored session. See [README_ACCOUNTS.md](README_ACCOUNTS.md) for the Apple challenge/login/refresh/logout/subscription contract and required Apple configuration. All content transactions recheck their request-scoped session after acquiring the database transaction; a request authenticated before logout cannot later write new content.

The old provisioning CLI and HS256-only sessions remain for isolated synthetic tests, explicitly selected with `create_app(service, managed_accounts=False)`. They are not accepted by the default managed routes and must not be used to grant production API access. The real flow derives identity from Apple and paid access from independently verified, account-bound App Store transactions/current status, with at most a five-minute lease. No request can grant itself `premium` or select another owner.

## JSON contract

The memory/CRUD dates below are UTC ISO 8601 strings; the separate account contract uses Unix timestamps. Unknown request fields are rejected. These content routes require `Authorization: Bearer <first-party session>`. IDs on routes select data belonging to the bearer subject only. A different account sees 404 for inaccessible IDs.

| Method and route | Body or response |
| --- | --- |
| `GET /v1/memory/settings` | `{enabled,premium_active,revision}`; default `enabled:false` |
| `PATCH /v1/memory/settings` | Body `{enabled:Bool}`; returns settings |
| `GET /v1/memory` | `{items:[Memory],revision}` |
| `POST /v1/memory` | `{kind,text,confirmed:true,source_conversation_id?:String}`; returns new Memory, status 201 |
| `PATCH /v1/memory/{id}` | `{text,kind?:String,confirmed:true}`; returns corrected Memory |
| `DELETE /v1/memory/{id}` | `{deleted:true}` |
| `GET /v1/conversations` | `{items:[{id,title,created_at,updated_at}]}` |
| `GET /v1/conversations/{id}` | `{conversation:Summary,messages:[{id,role,content,created_at}]}` |
| `DELETE /v1/conversations/{id}` | Deletes the conversation, all its turns and memories explicitly linked to that source; `{deleted:true}` |
| `DELETE /v1/conversations` | Same for all conversations belonging to this account |
| `GET /v1/account/export` | Versioned JSON of server settings, all memories, conversations and messages belonging to this account |
| `DELETE /v1/account/data` | Clears all server memories/conversations/messages, turns memory off, invalidates pending replies; `{deleted:true}` |

`Memory` is `{id,kind,text,source_conversation_id,created_at,updated_at}`. Kinds are `profile`, `preference`, `relationship`, `goal`, `note`. A profile is simply an explicit note, such as a preferred name; no inferred birth data, contact import or profile enrichment occurs.

`POST /v1/chat` accepts:

```json
{
  "message": "I prefer quiet mornings. Help me plan tomorrow.",
  "conversation_id": null,
  "temporary": false,
  "persist": false,
  "suggest_memories": true,
  "local_context": [
    {"id": "local-memory-id", "kind": "goal", "text": "I want a calmer morning routine."}
  ],
  "local_history": [
    {"role": "user", "content": "Tomorrow will be busy."},
    {"role": "assistant", "content": "What is the first small thing you need?"}
  ]
}
```

The response is `{conversation_id:String|null,message:{id,role:"assistant",content,created_at},used_memory_ids:[String],persisted:Bool,memory_suggestions:[{kind,text,source_quote}]}`.

These are the distinct chat modes:

| Mode | Context read | Server persistence | Suggestions |
| --- | --- | --- | --- |
| Native `persist:false` | Only the explicitly supplied local context/history | None | Only if `suggest_memories:true` |
| Temporary `temporary:true,persist:false` | Only in-session `local_history`; client keeps it in RAM and discards it on close | None | Always none |
| Server `persist:true` and memory enabled | At most six relevant saved memories and eight recent messages from this account's specified conversation | User and assistant turns saved together after a successful response | Only if explicitly requested |
| Server memory disabled | No saved context/history | None | None |

Temporary requests reject `local_context` and any saved `conversation_id`. Native stateless requests reject server conversation IDs. Server-persisted requests reject local context/history. The API cannot inspect whether a client's temporary history truly came from RAM; the client is responsible for sending only that current temporary session. There is no automatic import of server history.

All chat modes require an active server-side entitlement. On expiration, new memory creation, enabling memory and all model calls stop. Reading, exporting, correcting existing memories, disabling memory and deletion remain available with a valid authenticated session. Ordinary settings-off preserves saved data for the user to manage; erase is a separate action.

Suggestions use the same model request with structured output, incur no second extraction call, and are never inserted into the memory table. At most two candidates are returned; each candidate must contain a `source_quote` that is a literal substring of the **current user message**. This check establishes provenance, not truth: the user must review the text and explicitly confirm it before saving. No automatic memory is extracted from assistant answers, old history or a deleted memory. A model failure or incomplete/malformed response produces a generic 502, not a partial saved conversation.

## Data lifecycle and limits

- Every content table includes the authenticated subject in its primary/foreign keys. Queries, updates, exports and cascading deletes are scoped to it. Clients cannot switch ownership through a body field.
- The database file is created with 0600 permissions; new parent folders use 0700. SQLite `secure_delete` is enabled. This is **not application-level encryption or end-to-end encryption**. Encrypted disks, secrets, backups and operational access controls are still required before hosting real personal data.
- Account storage is bounded at 100 memories, 200 conversations and 200 messages per conversation. A memory has 1,000 characters; a current message has 4,000. Both server and native memory context are bounded to six notes and 3,000 characters total, with eight history messages; chat/CRUD JSON bodies are capped at 128 KiB, including chunked uploads. The separate snapshot route allows a 2 MiB envelope with at most 1.9 MB archive content. There is no unbounded full-history model prompt.
- The initial retrieval method ranks a small corpus by lexical overlap and includes profile notes, with a maximum of six records. It is not a vector database, semantic search, or a tested multilingual recall guarantee.
- The default rate is 10 model requests/minute/account and 120 API requests/minute/account. Counters are persisted and scoped by authenticated subject. Deploy a global budget cap, unauthenticated/IP protection and perimeter concurrency limits as well; per-account throttling alone is not a complete cost-control system.
- Server history and confirmed memory have no automatic expiry in this beta; users can clear/export them. Expiring a subscription does not delete personal data. Set and disclose a retention/backup policy before production.
- Deleting a saved memory removes that memory record. The same facts may still be written in an old conversation; resuming that conversation can show those user-written facts in its recent history. Delete the source conversation too to stop that history being supplied. A deletion cannot retract data already sent in an in-flight provider request.
- Concurrent clearing, changing settings, editing/deleting memory, entitlement revocation or entitlement expiration are rechecked after model generation. A conflicting pending reply is discarded with 409/403 and is not saved or returned. A failed provider request never leaves an orphan user turn.
- `DELETE /account/data` removes memory/chat content and disables memory. It retains the opaque subject's subscription expiration, mutation revision and minimal rate counters so that pending work cannot resurrect data and erased accounts cannot reset abuse limits. The separate `DELETE /account` flow revokes Apple access then removes account identity, every session, subscription binding and content; deployment still needs backup-retention and interrupted-deletion recovery procedures.
- Native `persist:false` still authenticates and rate-limits. It leaves no conversation content in this SQLite service. The iOS data export/delete must target its own archive; the server export/delete routes cover only data actually stored on the server.
- The adapter sends `store:false`, has no Responses `conversation`/`previous_response_id`, no tools, no developer-controlled external provider URL, and does not follow redirects. Personal context is JSON-quoted lower-trust input, never interpolated into system instructions. These measures constrain exposure but do not prove immunity to prompt injection.
- There is no prompt/body/credential application logging. Disable proxy/access payload capture and debug tracing before deployment. The service processes the selected content and OpenAI processes it when configured. `store:false` controls Responses application state; it **does not promise zero retention across all provider abuse-monitoring systems**.

## Verification and production gaps

Run `python -m pytest tests/test_memory.py`. Tests use temporary SQLite files, synthetic accounts, injected `FakeResponder`, and `httpx.MockTransport`; no real account, provider key, network model request or charge is involved. Tests cover isolation, session tampering/expiration, owner-forgery rejection, opt-in, CRUD/export/erase, expiry access, source cascades, temporary/native modes, prompt context bounds, provider failures, concurrent deletion/revocation, limits, restart persistence, structured suggestion provenance and no provider redirects.

Before release: configure real Apple credentials and API key/model; verify the native flow against Apple sandbox and real devices; connect Apple account-state notifications and operational interrupted-deletion recovery; evaluate model quality; host over HTTPS with encrypted storage/backups, explicit retention and spend caps; update the published privacy policy and store disclosures. The implemented flows do not establish that this production verification has happened. [Deployment preparation](../docs/RENDER_DEPLOYMENT.md).

Official API references checked for this implementation:

- [Responses create: store, input and output](https://developers.openai.com/api/reference/cli/resources/responses/methods/create)
- [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs)
- [OpenAI platform data controls](https://developers.openai.com/api/docs/guides/your-data)
