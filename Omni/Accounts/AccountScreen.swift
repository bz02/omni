import AuthenticationServices
import SwiftUI

struct AccountScreen: View {
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var subscription: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    @State private var signOut = false
    @State private var delete = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: "YOUR OWN ACCOUNT", title: account.isSignedIn ? "A space\nthat's yours." : "Bring a little\ncontinuity.", subtitle: "Sign-in is optional. Purchase and restore on-device Plus without an Omni account. Sign in to connect online conversations and account memory sync.")
                    if !account.hasConfiguration {
                        OmniCard(color: OmniTheme.sage) {
                            Text("Accounts aren't connected yet.").font(OmniTheme.title(25))
                            Text("Your local journal and saved details remain available. Account access will appear here when the service is ready.").font(.subheadline)
                        }
                    } else if let accountID = account.accountID {
                        OmniCard(color: OmniTheme.sage) {
                            Label("Signed in with Apple", systemImage: "checkmark.shield")
                            Text("Account \(accountID.uuidString.prefix(8).lowercased())").font(.caption).foregroundStyle(OmniTheme.muted)
                            Text(account.hasOnlinePremium ? "Online Plus is active" : "Online Plus hasn't been verified for this account").font(.subheadline)
                            Button("Check subscription") { Task { await subscription.syncAccountEntitlements(); await account.refreshAccount() } }
                                .accessibilityIdentifier("account.checkSubscription")
                        }
                        Text("Account memories are separate from your guest records. Signing in does not upload your local journal or automatically move guest memories into this account.")
                            .font(.subheadline).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                        Button("Sign out on this device") { signOut = true }.accessibilityIdentifier("account.signOut")
                        Button("Delete my Omni account", role: .destructive) { delete = true }.accessibilityIdentifier("account.delete")
                    } else {
                        OmniCard {
                            Text("A private way to sign in.").font(OmniTheme.title(25))
                            Text("Apple confirms your identity to Omni. Your Apple identity token and authorization code go to Omni's account service to complete sign-in; the app keeps only its session in the iPhone Keychain.").font(.system(size: 14)).lineSpacing(4)
                            Text("If you have Plus, signing in links an unlinked subscription to this Omni account for online access. Your guest memories and journal aren't automatically uploaded or merged. Online conversations ask for separate permission before sharing conversation content.").font(.system(size: 13)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                        }
                        if account.challengeReady {
                            SignInWithAppleButton(.signIn) { request in account.configureAppleRequest(request) } onCompletion: { result in
                                Task { await account.completeSignIn(result); if account.isSignedIn { await subscription.syncAccountEntitlements() } }
                            }.signInWithAppleButtonStyle(.black).frame(height: 54).clipShape(RoundedRectangle(cornerRadius: 14))
                                .disabled(account.isBusy).accessibilityIdentifier("account.appleSignIn")
                        } else {
                            OmniButton(title: "Prepare secure sign-in", icon: "lock.shield") { Task { await account.prepareSignIn() } }
                                .disabled(account.isBusy).accessibilityIdentifier("account.prepare")
                        }
                    }
                    if account.isBusy { ProgressView("Connecting securely…") }
                    if let error = account.errorMessage { Text(error).font(.subheadline).foregroundStyle(OmniTheme.muted).accessibilityIdentifier("account.error") }
                    Text("Deleting your Omni account doesn't cancel an Apple subscription. Manage your subscription in your App Store account settings.").font(.system(size: 12)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                }.padding(24)
            }.background(OmniTheme.paper).foregroundStyle(OmniTheme.ink)
                .navigationTitle("Account").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() }.accessibilityIdentifier("account.done") }
                .task { if account.isSignedIn { await account.refreshAccount() } else if account.hasConfiguration { await account.prepareSignIn() } }
                .confirmationDialog("Sign out of your Omni account on this device?", isPresented: $signOut, titleVisibility: .visible) {
                    Button("Sign out") { Task { _ = await account.signOut() } }
                } message: { Text("Sign out disconnects this account. Its protected memory cache stays on this iPhone and is available when you sign in to the same account again. Your guest journal stays on this device.") }
                .confirmationDialog("Permanently delete your Omni account?", isPresented: $delete, titleVisibility: .visible) {
                    Button("Delete account", role: .destructive) {
                        let deletingID = account.accountID
                        Task {
                            _ = await account.deleteAccount()
                            if let deletingID, account.lastDeletedAccountID == deletingID {
                                do { try MemoryStore.removeAccountCache(deletingID) }
                                catch { account.reportCacheDeletionFailure() }
                            }
                        }
                    }
                } message: { Text("This deletes account data from Omni and revokes its Apple sign-in access. Export anything you want to keep first. Your guest journal and Apple subscription are managed separately.") }
        }
    }
}
