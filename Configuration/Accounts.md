# Native Apple accounts

The account layer is ready for integration testing. Production Apple sign-in has not been exercised with a deployed service or Apple Developer provisioning in this task.

## Configuration and lifecycle

- Configure `OMNI_MEMORY_API_URL` to the first-party HTTPS service root. It must not contain URL credentials, query parameters or fragments. Debug builds allow loopback HTTP for local testing only. No configured service means no account UI authentication or account-bound purchase requirement.
- Enable Sign in with Apple for the app's actual Bundle ID and signing profile. Never bundle Apple client secrets, provider API keys or server signing keys in the app.
- Inject one `AccountStore` through the app environment and assign it to `SubscriptionStore.accountStore`. On foreground and account changes, refresh the account status and local StoreKit entitlements; sync verified transactions when signed in.
- `AccountScreen()` shows the real `SignInWithAppleButton`. It prepares `/v1/auth/challenge` before the button is enabled, hashes the server nonce with SHA-256, and binds the challenge ID as Apple request state. The completed identity token and authorization code are sent once to `/v1/auth/apple`; they are never persisted by the app.
- Only Omni access/refresh tokens, account UUID and token expiry are saved in the iPhone Keychain with `WhenUnlockedThisDeviceOnly`. The Keychain entry is scoped to the service URL. The guest journal and guest memories are not uploaded or merged on sign-in.
- `validAccessToken()` shares one refresh among concurrent callers. Refresh tokens rotate, so a failed or uncertain refresh clears local authentication and requires fresh Apple sign-in; it is never automatically replayed. `authenticatedRequest` retries a rejected access token once after refreshing.
- `accountID` is the identity observation point for the root's separate account memory scope. Sign-out preserves the protected account cache for the same account's next sign-in. Successful account deletion also calls `MemoryStore.removeAccountCache(accountID)`; a cache-removal failure is reported separately.

## Subscription binding

With a configured account service, new StoreKit purchases require a signed-in account and supply `.appAccountToken(accountID)`. Local Plus and outbound transaction sync accept only transactions bound to that account. Unconfigured builds retain the existing offline StoreKit behavior.

`syncAccountEntitlements()` sends only `VerificationResult.verified` transactions' `jwsRepresentation` to `/v1/account/subscription`. The server independently validates Apple signatures, product, app identity, environment, expiry and account token before granting online access. A local `hasPremium` value is not proof of server entitlement. Unbound legacy purchases are not silently attached to a newly signed-in user.

Server status comes from `/v1/account/session`. Refunds and renewals still require production App Store Server Notifications and/or server reconciliation to keep online access current after the app is closed; check the backend deployment checklist.

## Tests and operational limits

`AccountTests` uses synthetic responses and an in-memory vault to cover endpoint restrictions, nonce hashing, concurrent refresh, rejected access tokens, uncertain refresh, sign-out races, deletion failures and transient Apple credential handling. It does not fake a successful Apple user login or establish that production provisioning works.

Sign-out tries to revoke the server session, but it removes local access even when the network is unavailable. Account deletion keeps the session if the server reports failure, allowing retry. Deleting an Omni account never cancels the customer's Apple subscription.

## Primary references

- [Apple authorization requests](https://developer.apple.com/documentation/authenticationservices/asauthorizationappleidrequest)
- [Apple nonce property](https://developer.apple.com/documentation/authenticationservices/asauthorizationopenidrequest/nonce)
- [StoreKit purchase options](https://developer.apple.com/documentation/storekit/product/purchase(options:))
- [App account token](https://developer.apple.com/documentation/storekit/product/purchaseoption/appaccounttoken(_:))
- [Verified transaction JWS](https://developer.apple.com/documentation/storekit/verificationresult/jwsrepresentation-21vgo)
