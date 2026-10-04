# Connect discovery implementation and launch conditions

October 4 positioning update: friendship is now the default. Friendship profiles accept optional gender and welcome all genders; only age bounds filter them. Legacy dating profiles keep their audience and remain in a separate pool; switching requires explicit `friends-v1` consent and re-review. API/table names retain `dating` for compatibility, not product positioning. The local demo now uses `/private/tmp/omni-friends-preview.sqlite3` and preserves the old database. User-facing language is “Let’s connect” / “Connections” / “On a similar wavelength.” Birth elements remain symbolic conversation context, not a scientific energy-field measurement.


Updated October 3, 2026. This is local development, not a claim that discovery is live. App Store 1.1 remains unchanged. The existing 1.2 Build 8 invitation-only draft does not contain this increment and must not be submitted as the requested full dating product.

## Implemented

- Private birthday, optional birth time, birth city/timezone, longitude and DST-fold inputs. iOS uses Apple's city search without device-location access. Web invitations accept local clock time and a timezone. No five-element selector; legacy API values are accepted for backward compatibility but do not override new calculations.
- Deterministic lunar-python day-master element and visible eight-character element counts. Year/month use exact Jie Qi evaluated in UTC+08; day/hour use local mean solar time when longitude is present, otherwise civil time, with midnight day boundary. This is not apparent solar time, Xi/Yong Shen or an exact Western natal chart. Timezone gaps/repeated times are rejected unless resolved. Unknown birth time excludes the element dimension.
- Seven-dimension report shared between invitations and discovery. Goals, communication, priority and social pace carry 85% nominal weight; approximate calendar Sun sign, five elements and optional MBTI carry 15%. Missing inputs are excluded with remaining weights normalized. This is a disclosed creative conversation index, not empirical romantic-success probability.
- Authenticated opt-in adult profiles; mutual gender/age preference filtering; actual approved visible accounts only. No fabricated production people. Discovery is ranked in-app, not APNs push delivery. City is shown but distance filtering is not implemented.
- Like, persistent Pass, list of sent unmatched Likes, withdraw Like, reciprocal Match, authenticated conversation, block/report/unmatch, account export/deletion. An existing Match requires explicit Unmatch rather than a silent unlike.
- One optional photo per profile. Native PhotosPicker selects only the chosen image. Server accepts JPEG/PNG, 1 MB input/12 MP limit, minimum 100 pixels, recompresses to max 1000 pixels and strips metadata. SQLite blob is account-owned and cascades on deletion. Access requires ownership or approved compatible discovery / existing match; pending, suspended, blocked, ineligible and unrelated accounts cannot fetch it. Cache-Control no-store. Upload invalidates approval and increments revision; stale approval/delete fails.
- Photo review uses a private operator export, never a public admin endpoint. No AI photo or attractiveness ranking. No automatic outgoing invitations, social imports or paid model calls for matching.

## Local testing

Run from the project root:

```sh
backend/.venv/bin/python scripts/connect_local_demo.py
```

Open http://127.0.0.1:8765/demo. This loopback-only sandbox uses fixed fictional adult accounts Alex/Jamie/Riley in `/private/tmp/omni-connect-preview.sqlite3`, separate from production. The demo script and assets are outside the backend Docker image; synthetic session and approval routes must never be deployed. Use fictional information, switch profiles to Like back, inspect Matches, edit profiles, and upload an optional test photo. New photos require the explicitly labelled local simulated approval. Existing invitation links on the same local database continue to work. The app's Debug build exposes the Dating entry; Release remains off pending the conditions below.

## Operator commands

Run only in the protected server environment. Queue output contains personal data; never copy it into CI, public issues or Git.

```sh
python -m omni_memory.moderation queue
python -m omni_memory.moderation photo PROFILE_ID --revision REVIEWED_REVISION --output /private/review-photo.jpg
python -m omni_memory.moderation profile PROFILE_ID --revision REVIEWED_REVISION --decision approve
python -m omni_memory.moderation profile PROFILE_ID --revision REVIEWED_REVISION --decision suspend
python -m omni_memory.moderation resolve-report REPORT_ID
```

Review the actual photo and public fields at the exact revision, then delete the exported private review copy. Photo export creates a new owner-only file and refuses overwrite. Reporting immediately blocks and deletes the conversation, so the report form asks for an issue description; report context is limited to user-provided detail. Do not promise staffing or response deadlines until an operator is assigned.

## Required before public release

Assign a responsible profile/photo/report operator. The owner has not yet named one. Complete accurate App Store privacy and age declarations for public profiles, photos, gender/dating preferences and messaging; earlier invitation-only privacy consent is insufficient for these additions. Verify real signed-in iPhone photo upload, city search, deletion and discovery against a staging service. Then enable the release entry/service together, create a new build and update screenshots/review notes. Preserve US/18+ and approved subscription prices. No current account agreements, fees or Apple declarations were changed in this local increment.

## AI images and shared budget

`OMNI_IMAGES_ENABLED=true` and the existing server-side `OPENAI_API_KEY` enable `/v1/cosmos/images`. No key is shipped in the app. Generation requires a valid account, server-verified Plus and per-request consent. The model is `gpt-image-2`, one low-quality 1024-square JPEG. Only fixed-choice sign/theme/mood/occasion fields enter the prompt; birth records, journal, memories, dating records and free-form prompts are excluded.

One image attempt per account per UTC day, including failed/uncertain attempts. Request IDs cannot be replayed to trigger another generation. An uncertain image request reserves $0.10 from the shared allowance and is never automatically retried. The result is returned to the client, not stored by Omni; closing the screen discards the app's in-memory image. Provider retention remains governed by OpenAI's applicable API data controls, not by the app's local behavior.

The new `model_budget` table caps this deployment's chat/image allowance at $10 per UTC month. Each supported GPT-4.1 mini chat reserves $0.25 before the request; verified input/output usage reduces the reservation using full, non-cached pricing. Invalid/missing usage or uncertain failures retain the reservation. Images retain their conservative $0.10 allowance. This protects concurrent requests with a database transaction and survives restarts. It is an application allowance, not an OpenAI billing cap: prior spend before deployment, use by other applications, taxes and provider price changes are outside it. Check the OpenAI project's billing limit as well. Raising the user's authorized budget requires approval.

Changing the chat model fails closed until its price/reservation is reviewed; the allowed chat models are `gpt-4.1-mini` and `gpt-4.1-mini-2025-04-14`. The images API must be verified on the owner's actual project before enabling. Local MockTransport tests made no external requests and prove no production image-generation success.

Official references checked September 30, 2026:

- [Image generation API](https://developers.openai.com/api/docs/guides/image-generation)
- [GPT-4.1 mini pricing](https://developers.openai.com/api/docs/models/gpt-4.1-mini)
- [GPT Image 2](https://developers.openai.com/api/docs/models/gpt-image-2)

## Still required for the full requested version

Google/email account integration is not implemented yet; the owner's Google Cloud/Firebase project information is pending. Official REST/auth and native OAuth documentation was reviewed, but no project, credential, service agreement or login provider was created. Existing Apple sign-in remains unchanged.

Full natal/transit/synastry production integration and its ephemeris licensing remain unresolved. The private calculation code and tests from the earlier increment are preserved. Do not present calendar Sun-sign matching as full birth-chart matching or the added memory form as a calculated natal chart.
