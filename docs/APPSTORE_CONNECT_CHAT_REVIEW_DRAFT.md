# Connect friendship and messages — release review draft

Status checked October 4: Apple 1.2 Build 8 was submitted at 00:37 PDT and is Waiting for Review (6092fdb1-1b69-411f-8620-d5a5ad06715b). That submission does not contain these chat changes. Preserve it unless the user explicitly chooses replacement. The user requires this next submission to include friend messaging. New release source enables the native friendship entry; server enablement and the items below are still pending. Do not describe the old Build 8 as a messaging release.

## Proposed What's New
Find your people with Omni Connect. Create an optional-photo friendship profile, discover adults on your wavelength, and connect by mutual choice. Once connected, keep the conversation going with private messages, quoted replies, unread counts and pinned conversations. Read receipts are yours to turn on or off. Birth-based insights offer conversation starters alongside your interests and communication preferences.

## Proposed review notes (finalize after enablement and build verification)
This update adds opt-in adult friendship discovery and direct text messaging after both users choose to connect. It preserves the existing AI reflection, memory, charts, outfits, invitations and subscriptions. All genders are welcome. Optional profile photos and public profile edits require manual approval before discovery. Messages are accessible only to both approved participants. Users can report, block, end a connection, delete their Connect profile or delete their account. Blocking and ending a connection remove active conversation records and prevent further contact. Human-to-human messages are not sent to OpenAI. Read receipts default off and are controlled per conversation. Compatibility scores are symbolic conversation aids, not relationship outcome predictions.

Provide Apple a working, authorized review path for two consenting test accounts on the production-equivalent service after release acceptance testing. Never inject fake public profiles or claim fictional demo accounts are real users. Do not paste credentials into this document or GitHub.

## Privacy declaration changes to review before publication
All below are linked to the user's account; none used for tracking or advertising. Existing names, user IDs, purchases, other user content and usage declarations remain, subject to final screen verification.

| Data category | Actual use | Purpose |
| --- | --- | --- |
| Contacts | Opt-in social graph: invitations, connection requests, matches, blocks. No phone-address-book import. | App functionality and personalization |
| Emails or Text Messages | Participant identifiers, private text messages, quoted-message references and delivery/read state | App functionality |
| Photos or Videos | One optional sanitized profile photo; no video | App functionality |
| Coarse Location | User-selected city and birth city; no device location permission | App functionality and personalization |
| Other Data Types | Birthday/time, derived elements/zodiac, self-described personality and preferences | App functionality and personalization |
| Sensitive Info | Legacy dating gender preferences can imply orientation. Conservatively disclose Sensitive Info for this supported field; friendship does not require or infer orientation. | App functionality and personalization |

These are proposed classifications, not a published attestation. Proposed conservative classification: Sensitive Info for supported legacy dating preferences, Coarse Location for user-selected cities. Birth city search uses a selected city's center longitude, not the device's current location. The public profile shows chosen city, never exact private birth fields.

Apple definitions: https://developer.apple.com/app-store/app-privacy-details/ (checked October 4, 2026). Contacts includes social graph; messages include content and participants. The bundled manifest now includes these categories using Apple's documented identifiers; App Store Connect publication remains pending approval.

## Outstanding release actions
1. Name the person who will review profiles/photos/reports; establish queue access and response routine.
2. Confirm precise revised privacy disclosures and Apple publication attestation. The earlier Contacts wizard auto-review refusal was not bypassed; the new photo and messaging scope also exceeds the earlier invitation-only declaration request.
3. Confirm UGC/messaging age questionnaire answers while retaining the user's approved US 18+ positioning and prices ($7.99 monthly / $39.99 yearly).
4. Validate a real signed-in iPhone flow against staging, including photo upload, two-account chat, city search, reporting and deletion. Define protected backup retention and test restore before public enablement.
5. Enable release/service together after acceptance, upload the new signed build and truthful screenshots, bind it to 1.2, then submit. Do not submit old Build 8.

Instagram references: https://about.fb.com/news/2025/02/new-instagram-dm-features-stay-connected/ and https://about.fb.com/news/2020/09/new-messaging-features-for-instagram/ . This release borrows familiar pin/reply/inbox patterns; it does not connect to Instagram or send messages there.
