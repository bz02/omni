# Omni subscriptions

`Omni.storekit` is an **Xcode-only purchase simulation**, with proposed US test prices of $7.99/month and $39.99/year. It creates no products in App Store Connect, charges no money, and does not establish production availability. There is no trial configured. Both plans belong to the same subscription group and service level.

## Xcode testing

1. Open the app in Xcode and add this configuration file to the project if needed.
2. Edit Scheme → Run → Options → StoreKit Configuration → select `Omni.storekit`.
3. Verify a successful purchase, user cancellation, pending approval, restore, renewal, expiry, refund/revocation, and upgrades between plans with Xcode's StoreKit transaction manager. Relaunch and foreground the app during these cases. Confirm free users cannot open Plus content.
4. Switch StoreKit Configuration to **None** when testing real App Store Connect products in sandbox/TestFlight. Verify unavailable products display an unavailable state rather than a fake working purchase button.

## Production setup

Set `OMNI_PRIVACY_URL` and `OMNI_SUPPORT_URL` to the verified public HTTPS pages in the distribution build settings. Both settings are mapped into the generated application Info.plist in Debug and Release. Keep them empty until the actual pages are published; the Release paywall remains unavailable while either is missing. Setting shell environment variables alone does not configure the app—supply Xcode build settings or a release xcconfig, then verify the archived app's Info.plist contains the expected URLs.

Create auto-renewable subscriptions `omni.ai.Omni.plus.monthly` and `omni.ai.Omni.plus.yearly` in one App Store Connect subscription group. Configure approved prices, availability, localization, subscription review information, and the developer account's required agreements, tax, and banking details. The paywall must use StoreKit's `Product.displayPrice` and the actual subscription period. The proposed prices above must not be hardcoded into purchase buttons. Include working privacy policy, terms, restore purchases, and subscription management access.

Own one `SubscriptionStore` at app scope. Call `loadProducts()` for the paywall and `refreshEntitlements()` when the app becomes active. Gate paid views **and their actions** on `hasPremium`. The store grants access only from verified Apple transactions, checks expiry/revocation/upgrades, listens for updates, finishes verified transactions after processing, and handles verified billing grace periods. Basic daily content and the user's existing local journal remain usable without a subscription. No local preference or preview switch may override entitlement.

This client entitlement is for on-device features. The configured account API now verifies account-bound transactions and current subscription status independently; client booleans are not server authorization. See [Accounts.md](Accounts.md). Real Apple credentials and sandbox acceptance remain unconfigured.

## Apple references

- [Product and localized display prices](https://developer.apple.com/documentation/storekit/product)
- [Current entitlements, including billing grace periods](https://developer.apple.com/documentation/storekit/transaction/currententitlements)
- [Transaction verification, updates, and finishing](https://developer.apple.com/documentation/storekit/transaction)
- [Billing grace expiration](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/graceperiodexpirationdate)
- [StoreKit testing in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)

The JSON can be syntax-checked without Xcode. Full StoreKit behavior must be verified on an iOS simulator/device with Xcode and then Apple's sandbox before release.
