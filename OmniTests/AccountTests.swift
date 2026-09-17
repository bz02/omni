import AuthenticationServices
import Foundation
import Testing
@testable import Omni

@Suite("Account identity and rotating sessions", .serialized)
@MainActor
struct AccountTests {
    @Test("Account endpoints reject credentials, unencrypted remote hosts and configuration placeholders")
    func endpointAndNonce() {
        #expect(AccountConfiguration.validatedURL("https://omni.test") != nil)
        #expect(AccountConfiguration.validatedURL("http://omni.test") == nil)
        #expect(AccountConfiguration.validatedURL("https://name:secret@omni.test") == nil)
        #expect(AccountConfiguration.validatedURL("https://omni.test?token=secret") == nil)
        #expect(AccountConfiguration.validatedURL("$(OMNI_MEMORY_API_URL)") == nil)
        #expect(AccountConfiguration.nonceHash("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let vault = AccountTestVault(session: session(expired: false))
        let unconfigured = AccountStore(vault: vault, baseURL: nil)
        #expect(!unconfigured.hasConfiguration)
        #expect(unconfigured.accountID == nil)
        #expect(vault.loads == 0, "An unconfigured build must not expose a stored production identity.")
    }

    @Test("Parallel token consumers share one rotating refresh and persist the replacement")
    func refreshSingleFlight() async throws {
        let original = session(expired: true)
        let transport = AccountTestTransport(accountID: original.accountID)
        let vault = AccountTestVault(session: original)
        let account = AccountStore(transport: transport, vault: vault, baseURL: nil)
        async let first = account.validAccessToken()
        async let second = account.validAccessToken()
        let values = try await (first, second)
        #expect(values.0 == "new-access" && values.1 == "new-access")
        #expect(await transport.refreshes == 1)
        #expect(vault.saved?.refreshToken == "new-refresh")
        #expect(vault.saves == 1)
        let reopened = AccountStore(transport: transport, vault: vault, baseURL: nil)
        #expect(try await reopened.validAccessToken() == "new-access")
        #expect(await transport.refreshes == 1)
    }

    @Test("An authenticated request retries once with the rotated token after a 401")
    func unauthorizedRetry() async {
        let original = session(expired: false)
        let transport = AccountTestTransport(accountID: original.accountID)
        await transport.setRejectOldAccess(true)
        let account = AccountStore(transport: transport, vault: AccountTestVault(session: original), baseURL: nil)
        await account.refreshAccount()
        #expect(account.hasOnlinePremium)
        #expect(await transport.refreshes == 1)
        #expect(await transport.statusTokens == ["old-access", "new-access"])
    }

    @Test("An uncertain refresh is not replayed and requires fresh Apple sign-in")
    func uncertainRefreshClearsSession() async {
        let original = session(expired: true)
        let transport = AccountTestTransport(accountID: original.accountID)
        await transport.setRefreshFailure(true)
        let vault = AccountTestVault(session: original)
        let account = AccountStore(transport: transport, vault: vault, baseURL: nil)
        await #expect(throws: AccountError.refreshUncertain) { try await account.validAccessToken() }
        #expect(account.accountID == nil)
        #expect(vault.saved == nil)
        await #expect(throws: AccountError.signInRequired) { try await account.validAccessToken() }
        #expect(await transport.refreshes == 1)
    }

    @Test("Sign-out prevents an in-flight refresh from restoring the old account")
    func signOutCancelsRefresh() async throws {
        let original = session(expired: true)
        let transport = AccountTestTransport(accountID: original.accountID)
        let vault = AccountTestVault(session: original)
        let account = AccountStore(transport: transport, vault: vault, baseURL: nil)
        let request = Task { try await account.validAccessToken() }
        try await Task.sleep(for: .milliseconds(10))
        #expect(await account.signOut())
        _ = await request.result
        #expect(account.accountID == nil)
        #expect(vault.saved == nil)
        #expect(await transport.logoutTokens == ["old-refresh"])
    }

    @Test("Failed remote deletion preserves access; successful deletion clears the session")
    func deleteFailureAndSuccess() async {
        let original = session(expired: false)
        let transport = AccountTestTransport(accountID: original.accountID)
        await transport.setDeleteFailure(true)
        let vault = AccountTestVault(session: original)
        let account = AccountStore(transport: transport, vault: vault, baseURL: nil)
        #expect(!(await account.deleteAccount()))
        #expect(account.accountID == original.accountID)
        #expect(vault.saved != nil)
        #expect(account.lastDeletedAccountID == nil)
        await transport.setDeleteFailure(false)
        #expect(await account.deleteAccount())
        #expect(account.accountID == nil)
        #expect(vault.saved == nil)
        #expect(account.lastDeletedAccountID == original.accountID)
    }

    @Test("Apple sign-in binds the prepared nonce and stores only the Omni session")
    func appleChallengeAndExchange() async throws {
        let accountID = UUID()
        let transport = AccountTestTransport(accountID: accountID)
        let vault = AccountTestVault()
        let account = AccountStore(transport: transport, vault: vault, baseURL: nil)
        await account.prepareSignIn()
        #expect(account.challengeReady)
        let request = ASAuthorizationAppleIDProvider().createRequest()
        account.configureAppleRequest(request)
        #expect(request.nonce == AccountConfiguration.nonceHash("test-nonce-that-is-at-least-32-characters"))
        #expect(request.state == "one-use-challenge")
        try await account.exchangeAppleCredential(identityToken: "synthetic-apple-identity", authorizationCode: "synthetic-apple-code", challengeID: "one-use-challenge")
        #expect(account.accountID == accountID)
        #expect(vault.saved?.accessToken == "new-access")
        let body = try #require(await transport.appleBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json["authorization_code"] == "synthetic-apple-code")
        #expect(json["challenge_id"] == "one-use-challenge")
        let persisted = try JSONEncoder().encode(try #require(vault.saved))
        #expect(!String(decoding: persisted, as: UTF8.self).contains("synthetic-apple"))
    }

    private func session(expired: Bool) -> AccountSession {
        AccountSession(accountID: UUID(), accessToken: "old-access", refreshToken: "old-refresh",
                       expiresAt: Date().addingTimeInterval(expired ? -1 : 3600).timeIntervalSince1970)
    }
}

@MainActor
private final class AccountTestVault: AccountSessionPersisting {
    var saved: AccountSession?
    var loads = 0
    var saves = 0
    init(session: AccountSession? = nil) { saved = session }
    func load() throws -> AccountSession? { loads += 1; return saved }
    func save(_ session: AccountSession) throws { saves += 1; saved = session }
    func remove() throws { saved = nil }
}

private actor AccountTestTransport: AccountTransport {
    let accountID: UUID
    var refreshes = 0
    var statusTokens: [String] = []
    var logoutTokens: [String] = []
    var appleBody: Data?
    private var rejectOldAccess = false
    private var refreshFailure = false
    private var deleteFailure = false
    init(accountID: UUID) { self.accountID = accountID }
    func setRejectOldAccess(_ value: Bool) { rejectOldAccess = value }
    func setRefreshFailure(_ value: Bool) { refreshFailure = value }
    func setDeleteFailure(_ value: Bool) { deleteFailure = value }
    func request(path: String, method: String, body: Data?, accessToken: String?) async throws -> Data {
        switch path {
        case "/v1/auth/challenge":
            return try JSONSerialization.data(withJSONObject: ["challenge_id": "one-use-challenge", "nonce": "test-nonce-that-is-at-least-32-characters", "expires_at": Date().addingTimeInterval(300).timeIntervalSince1970])
        case "/v1/auth/apple":
            appleBody = body
            return try sessionData()
        case "/v1/auth/refresh":
            refreshes += 1
            try await Task.sleep(for: .milliseconds(70))
            if refreshFailure { throw URLError(.timedOut) }
            return try sessionData()
        case "/v1/account/session":
            statusTokens.append(accessToken ?? "")
            if rejectOldAccess && accessToken == "old-access" { throw AccountError.http(401) }
            return try JSONSerialization.data(withJSONObject: ["account_id": accountID.uuidString, "premium_until": Date().addingTimeInterval(3600).timeIntervalSince1970, "premium_active": true])
        case "/v1/auth/logout":
            if let body, let json = try JSONSerialization.jsonObject(with: body) as? [String: String], let token = json["refresh_token"] { logoutTokens.append(token) }
            return Data()
        case "/v1/account":
            if deleteFailure { throw AccountError.http(503) }
            return Data()
        default: throw AccountError.http(404)
        }
    }
    private func sessionData() throws -> Data {
        try JSONEncoder().encode(AccountSession(accountID: accountID, accessToken: "new-access", refreshToken: "new-refresh", expiresAt: Date().addingTimeInterval(3600).timeIntervalSince1970))
    }
}
