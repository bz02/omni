# Shipping Omni to the App Store

The `iOS App Store upload` workflow (`.github/workflows/ios-release.yml`) does the
machine half of a release: it archives a signed Release build, exports an App Store
IPA, validates it, and uploads it to App Store Connect.

It does **not** submit the app for review, and it cannot run until the Apple-side
account work below is done by a person with access to the developer account.

## What only a human can do

None of this can be automated from CI, and none of it has been done yet.

1. **Apple Developer Program membership** for team `MGFX73F82F`, with the paid
   membership active and the Program License Agreement, tax forms and banking
   details accepted in App Store Connect. Paid-app agreements are required before
   subscriptions can be sold.
2. **App record** in App Store Connect for bundle ID `omni.ai.Omni`, with the
   bundle ID registered in the Developer portal first.
3. **Subscriptions.** Create `omni.ai.Omni.plus.monthly` and
   `omni.ai.Omni.plus.yearly` in one subscription group, with prices, availability,
   localizations and subscription review information. Until these exist and are
   approved, the paywall has nothing to sell. See
   [Configuration/README.md](../Configuration/README.md).
4. **Public pages.** `OMNI_PRIVACY_URL` and `OMNI_SUPPORT_URL` currently point at
   `https://omni-memory-beta.onrender.com`. Review rejects builds whose privacy
   policy or support page 404s, sits behind a login, or describes a different
   product. The workflow HEAD-checks both URLs and refuses to build if either is
   unreachable — but reachable is not the same as correct, so read the pages.
5. **Store listing**: name, subtitle, description, keywords, screenshots for every
   required device size, age rating, category, and the App Privacy questionnaire
   (which must match `Omni/PrivacyInfo.xcprivacy` and what the backend actually
   collects).
6. **Signing assets** — see below.
7. **Submit for review**, and answer whatever Review asks. Astrology, tarot and
   MBTI apps draw extra scrutiny under App Review Guideline 4.3 (spam) and 2.3.1
   (accurate metadata); do not describe readings as predictive fact.

## Secrets the workflow needs

Set these on the `app-store` environment in repository settings. Never commit them.

| Secret | Where it comes from |
| --- | --- |
| `APPLE_DIST_CERT_P12_BASE64` | An Apple Distribution certificate exported from Keychain Access as `.p12`, then `base64 -i cert.p12 \| pbcopy` |
| `APPLE_DIST_CERT_PASSWORD` | The password chosen during that `.p12` export |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect → Users and Access → Integrations → App Store Connect API |
| `APP_STORE_CONNECT_ISSUER_ID` | The issuer ID shown on the same page |
| `APP_STORE_CONNECT_PRIVATE_KEY` | The full contents of the downloaded `AuthKey_<KEY_ID>.p8`, including the `BEGIN PRIVATE KEY` lines. Apple lets you download it once |

The API key needs the **App Manager** role to upload builds. Provisioning profiles
are fetched automatically through that key, so no profile secret is needed.

## Running it

1. Land the change on `main` and let `iOS release verification` pass.
2. Actions → *iOS App Store upload* → Run workflow.
3. Set `build_number` higher than any build already uploaded for marketing version
   `1.0`. It is not derived automatically, so App Store Connect rejects a repeat.
4. Leave `dry_run` **true** the first time. That signs, exports and validates the
   IPA without uploading, which is how you find signing and entitlement problems
   without burning a build number.
5. Re-run with `dry_run` set to false to upload.

The build appears in TestFlight once Apple finishes processing it. Test it there —
especially a real sandbox subscription purchase, restore, and expiry — before
creating the App Store version and submitting.

## Screenshots

`iOS App Store screenshots` (`.github/workflows/ios-screenshots.yml`) captures them
from the real app rather than from mockups: it boots a simulator whose native
resolution is a size Apple accepts, runs the `ClarityJourneyTests` and
`MemoryJourneyTests` journeys, and exports the screenshot attachments those tests
already record. Pick `iphone-6.9`, `ipad-13`, or `both`, then download the
`omni-screenshots-<class>` artifact.

`Omni` sets `TARGETED_DEVICE_FAMILY = "1,2"`, so it ships as an iPhone **and** iPad
app and App Store Connect will ask for both an iPhone 6.9" set and an iPad 13" set.
Run with `both`.

`scripts/extract_screenshots.py` checks every exported PNG against the accepted
pixel dimensions for that class and fails the run if one does not match, naming the
size it actually got. When that happens, change the simulator device — do **not**
rescale the images, because Apple rejects resampled screenshots.

What comes out is a raw capture of ten real screens, in test order. It is not a
finished store listing:

- Choose and order the ones that actually sell the app; the first two are what most
  people see.
- Drop any screen showing placeholder or test-authored content. The journeys type
  synthetic text such as "Take a quiet walk before dinner", and a screenshot must
  show what a real user would see.
- The journeys run with `OMNI_MEMORY_API_URL=''`, so anything requiring the backend
  renders in its offline or unavailable state. Those frames are not usable as-is.
- Marketing frames (device bezels, captions, backgrounds) are a design task and
  are deliberately not automated here.
- Screenshots must match the app's current build. Re-run after UI changes.

The tests set `-AppleLanguages (en)` and `-AppleLocale en_US`, so the output is the
English set only. Other locales would need those launch arguments parameterized.

## Bumping the version

`MARKETING_VERSION` (`1.0`) lives in `Omni.xcodeproj/project.pbxproj` and is the
public version number; change it there for a new release. `CURRENT_PROJECT_VERSION`
is overridden per run by the `build_number` input, so the value in the project file
only affects local builds.
