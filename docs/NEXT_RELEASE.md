# Omni 1.1 — personal astrology conversations

Decision recorded September 30, 2026: preserve the current app and add the requested features in a new version. Do not remove the released app, replace its user data, or discard existing functionality. Version 1.0 (5) was manually released and App Store Connect reported Ready for Distribution; public download availability was not yet confirmed in the last release check.

## Product and journeys

The next release expands Omni for US adults into astrology, dating discovery, daily style, and personal AI conversation. The existing Today, Connect, Talk, Journal, and You tabs remain available. Existing local guest use and purchases must keep working.

| Journey | Intended experience | Current implementation / remaining work |
| --- | --- | --- |
| Returning user | Open the updated app; find existing journal, account, memories and Plus entitlement intact | Existing persistence schemas and tabs retained. Regression verification required before release. |
| Daily astrology | Provide birth date, time (or explicitly unknown), birthplace and timezone; calculate natal chart; explain today's actual transits | Existing private chart engine plus new tested transit computation. Production account integration, chart UX and ephemeris licensing still unresolved. Unknown time must not invent an ascendant or houses. |
| Tarot | Ask a question; draw three distinct cards; discuss the actual draw with AI | Added local 78-card draw and a drafted question in the existing consent-controlled conversation. No automatic transmission. |
| Daily outfits | Select occasion, see color and outfit, personalize using saved preferences | Added authored sign-inspired daily outfits. This is not yet natal-chart/personal-memory-driven outfit generation. |
| Dating | Opt in to discovery; publish an adult profile; receive birth-chart-based suggestions; mutually like before conversation; block/report | Native screens and account-service discovery, mutual likes, messages, block/report, moderation queue and deletion added. Production remains disabled pending operational review. Current score uses disclosed approximate calendar Sun signs; full calculated synastry integration remains. |
| Account | Sign in with Apple, Google or verified email; keep the same account's memories and entitlements | Existing Apple flow retained. Google/email provider configuration, verification, linking and recovery are still to build. No merging accounts solely by unverified email. |
| AI memory | Talk with GPT; review remembered facts; correct, forget, export or delete them; use temporary conversations | Existing account-scoped memory and GPT gateway retained. Added an explicit birth/style memory form, using the existing edit/export/delete controls. Structured calculated-chart context remains to integrate. |
| Images | Generate a horoscope/outfit image; preview it; explicitly share | Existing local poster retained. Added consent-controlled native AI image studio and server OpenAI image adapter, Plus check, daily quota and shared monthly allowance. Mock tests only; production provider integration not yet verified or enabled. |

The dating intent is real opt-in discovery, not just an invite-only compatibility calculator. The Google project configuration and dating review operator questions are pending; no credentials should be sent in conversation.

## Second development increment — September 30, 23:56 PDT

- Added `Omni/Dating/` and authenticated `/v1/dating/` workflows. No real profiles were seeded and no messages were sent to people during development.
- Added a manual moderation console with exact-revision approval, plus public-content edit invalidation and server-enforced blocking. Dating is disabled by default until the operator and launch prerequisites are ready.
- Added `CosmicProfileScreen` to explicitly save/revise birth details and outfit preferences inside the current Memory archive without changing its schema or copying data into dating.
- Added `CosmicImageScreen`, `/v1/cosmos/images`, and a real OpenAI Image API adapter. It was tested with simulated provider responses, not a billed provider call. AI images remain disabled by default.
- Added the shared $10/month server allowance, atomic request reservations, per-account image attempts, replay protection and late-account-change checks. This is an app-level allowance, not control over unrelated OpenAI billing.
- Existing Apple sign-in, journals, five tabs and subscription IDs/prices are retained. Google/email is still unimplemented pending provider setup, and exact natal-chart integration is still pending.
- Backend regression tests and native tests are recorded below. Nothing in this increment has been pushed, deployed or submitted to Apple. Operations and remaining limitations: `Configuration/DatingAndImages.md`.
- Final local verification at 23:59 PDT: 199 backend tests passed; 72 native unit tests passed; four existing Clarity journeys passed; the new dating → cosmic-memory profile → AI-image studio → existing check-in journey passed after correcting nested button targeting and rerunning the current simulator test bundle. New logged-in production/provider journeys remain unverified. New feature UI evidence: `/private/tmp/omni-v11-final-previews/`.

## Current development increment

- `Omni/Cosmos/`: additive Cosmos screen, 78-card Fisher–Yates tarot draw, daily creative outfits, local share image.
- Today opens Cosmos; all five original tabs remain.
- Existing conversation accepts an optional initial draft, preserving its entitlement and consent gates.
- Private `/v1/synastry` and `/v1/transits` routes use the existing authorized astronomical engine. Interpretive indices disclose their formula and are not relationship-success probabilities.
- No production deployment, App Store metadata change, version bump, new build upload or review submission has occurred for this increment.
- Existing staged files in the main checkout must not be reset, committed or overwritten by release preparation.

## Release acceptance

### Verification of the initial increment (September 30)

- iOS simulator build: succeeded.
- Python engine regression and new synastry/transit tests: 28 passed.
- Native unit tests (including existing memory, account, StoreKit, persistence and new Cosmos tests): 69 passed. The new DST regression initially found a same-day palette change; anchoring to civil-day start fixed it.
- iPhone 16 Pro / iOS 18.2: all four Clarity journey tests passed, including new Cosmos poster and return to existing check-in, journal persistence, connection records and privacy controls.
- iPad Air 11-inch / iOS 18.2: new Cosmos journey passed. Initial existing journey tests queried only the bottom tab bar, which does not match iPadOS 18's top navigation; the helper queries now support both. The remaining iPad journeys have not been rerun with that change.
- Test evidence is local under `/private/tmp/omni-v11-derived/Logs/Test/`. Screenshot inspection confirmed the new sharing control and tarot section render on iPhone. This is development verification, not production acceptance or confirmation of a published update.

### October 1 release scope (user priority)

Ship ready features now, preserving version 1.0: actual AI conversation with horoscope/love/career/outfit starters, clear sign-in and Plus recovery, Cosmos daily outfits and locally generated share cards, actual tarot draws, and explicitly saved birth/style memory. Dating discovery, Google/email sign-in, generated AI images and exact production natal/transit integration remain future work and must not block this release. Hide unfinished dating/image entry points with `ReleaseFeatures`; retain their implementation for the later release.

CUJ: Open Talk → choose a topic or type freely → Apple sign-in if needed → existing Plus purchase or restore → consent to send to OpenAI → real model reply → follow-up using bounded recent history and relevant user-approved memory. If no birth details/sign exist, ask a single useful question. Temporary chat must still exclude saved memory. Never invent chart calculations. Offline daily outfits, tarot draw and existing reflections remain usable.

Acceptance: authenticated request and failure recovery tests; regression tests for original journals/accounts/subscriptions/memory; actual synthetic production model reply; deploy compatible server first; build version 1.1 using cloud Xcode; accurate review metadata, screenshots and submission. Keep US, 18+, original prices. No existing app withdrawal or data reset.

The old `omni` follow-up automation was deleted during the earlier scope change; it is not currently monitoring. This did not remove the app or change any production service.
