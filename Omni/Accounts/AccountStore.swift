import AuthenticationServices
import Combine
import Foundation

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accountID: UUID?
    @Published private(set) var premiumUntil: Date?
    @Published private(set) var isBusy = false
    @Published private(set) var challengeReady = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastDeletedAccountID: UUID?
    let hasConfiguration: Bool
    var isSignedIn: Bool { accountID != nil }
    var hasOnlinePremium: Bool { isSignedIn && (premiumUntil.map { $0 > Date() } ?? false) }

    private let transport: (any AccountTransport)?
    private let vault: any AccountSessionPersisting
    private var session: AccountSession?
    private var challenge: AccountChallenge?
    private var requestedChallengeID: String?
    private var generation = 0
    private var refreshTask: Task<AccountSession, Error>?
    private var refreshID: UUID?

    init(transport: (any AccountTransport)? = nil, vault: (any AccountSessionPersisting)? = nil,
         baseURL: URL? = AccountConfiguration.baseURL) {
        self.transport = transport ?? baseURL.map { AccountHTTPTransport(baseURL: $0) }
        self.vault = vault ?? AccountKeychainVault(namespace: baseURL?.absoluteString ?? "unconfigured")
        hasConfiguration = self.transport != nil
        guard hasConfiguration else { return }
        do {
            session = try self.vault.load()
            accountID = session?.accountID
        } catch { errorMessage = AccountError.secureStorage.localizedDescription }
    }

    func prepareSignIn() async {
        guard let transport, !isBusy else { return }
        isBusy = true; errorMessage = nil; challengeReady = false; challenge = nil
        let version = generation
        defer { if version == generation { isBusy = false } }
        do {
            let data = try await transport.request(path: "/v1/auth/challenge", method: "POST", body: nil, accessToken: nil)
            let result = try JSONDecoder().decode(AccountChallenge.self, from: data)
            guard version == generation else { return }
            guard !result.challengeID.isEmpty, result.challengeID.count <= 512, result.nonce.count >= 16, result.nonce.count <= 1024,
                  result.expiresAt > Date().timeIntervalSince1970 + 5 else { throw AccountError.invalidResponse }
            challenge = result; challengeReady = true
        } catch { if version == generation { errorMessage = message(for: error) } }
    }

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        guard let challenge, challenge.expiresAt > Date().timeIntervalSince1970 else {
            requestedChallengeID = nil; challengeReady = false; errorMessage = AccountError.expiredChallenge.localizedDescription
            // A missing/expired preparation cannot produce a usable backend login.
            request.nonce = AccountConfiguration.nonceHash(UUID().uuidString)
            return
        }
        requestedChallengeID = challenge.challengeID
        request.nonce = AccountConfiguration.nonceHash(challenge.nonce)
        request.state = challenge.challengeID
        request.requestedScopes = []
    }

    func completeSignIn(_ result: Result<ASAuthorization, Error>) async {
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8),
                  let codeData = credential.authorizationCode, let code = String(data: codeData, encoding: .utf8),
                  let challengeID = requestedChallengeID, credential.state == challengeID else { throw AccountError.invalidResponse }
            try await exchangeAppleCredential(identityToken: token, authorizationCode: code, challengeID: challengeID)
        } catch let error as ASAuthorizationError where error.code == .canceled {
            errorMessage = nil
        } catch { errorMessage = message(for: error) }
        requestedChallengeID = nil; challenge = nil; challengeReady = false
    }

    /// Only the short-lived Omni session is persisted. Apple credentials are sent
    /// once for server validation and revocation support, never stored by this app.
    func exchangeAppleCredential(identityToken: String, authorizationCode: String, challengeID: String) async throws {
        guard let transport else { throw AccountError.unavailable }
        guard challengeID == challenge?.challengeID, let challenge, challenge.expiresAt > Date().timeIntervalSince1970,
              !identityToken.isEmpty, identityToken.utf8.count <= 32768,
              !authorizationCode.isEmpty, authorizationCode.utf8.count <= 16384 else { throw AccountError.expiredChallenge }
        struct Body: Encodable { let challenge_id: String; let identity_token: String; let authorization_code: String }
        isBusy = true; errorMessage = nil
        let version = generation
        defer { if version == generation { isBusy = false } }
        let data = try await transport.request(path: "/v1/auth/apple", method: "POST",
                                               body: try JSONEncoder().encode(Body(challenge_id: challengeID, identity_token: identityToken, authorization_code: authorizationCode)), accessToken: nil)
        guard version == generation else { throw CancellationError() }
        let decoded = try decodeSession(data)
        try adopt(decoded)
        await refreshAccount()
    }

    func validAccessToken(forceRefresh: Bool = false) async throws -> String {
        guard let session, let transport else { throw AccountError.signInRequired }
        if let refreshTask { return try await refreshTask.value.accessToken }
        if !forceRefresh, session.expiresAt > Date().timeIntervalSince1970 + 60 { return session.accessToken }
        let id = UUID(), version = generation
        refreshID = id
        let task = Task<AccountSession, Error> { @MainActor in
            defer { if self.refreshID == id { self.refreshTask = nil; self.refreshID = nil } }
            do {
                struct Body: Encodable { let refresh_token: String }
                let data = try await transport.request(path: "/v1/auth/refresh", method: "POST",
                                                       body: try JSONEncoder().encode(Body(refresh_token: session.refreshToken)), accessToken: nil)
                guard version == self.generation, self.session?.accountID == session.accountID else { throw CancellationError() }
                let decoded = try self.decodeSession(data)
                guard decoded.accountID == session.accountID else { throw AccountError.invalidResponse }
                try self.adopt(decoded)
                return decoded
            } catch {
                if version == self.generation {
                    // A rotating refresh token is never retried after an uncertain
                    // response. Reusing it can revoke the server's token family.
                    _ = self.clearLocalSession()
                    self.errorMessage = AccountError.refreshUncertain.localizedDescription
                }
                throw AccountError.refreshUncertain
            }
        }
        refreshTask = task
        return try await task.value.accessToken
    }

    func authenticatedRequest(path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let transport, let expectedAccount = accountID else { throw AccountError.signInRequired }
        let version = generation
        let token = try await validAccessToken()
        guard accountID == expectedAccount else { throw AccountError.signInRequired }
        do {
            let data = try await transport.request(path: path, method: method, body: body, accessToken: token)
            guard version == generation, accountID == expectedAccount else { throw AccountError.signInRequired }
            return data
        }
        catch AccountError.http(401) {
            // Another request may have already replaced the rejected token.
            let refreshed = try await validAccessToken(forceRefresh: session?.accessToken == token)
            guard accountID == expectedAccount else { throw AccountError.signInRequired }
            let data = try await transport.request(path: path, method: method, body: body, accessToken: refreshed)
            guard version == generation, accountID == expectedAccount else { throw AccountError.signInRequired }
            return data
        }
    }

    func refreshAccount() async {
        let version = generation, expectedAccount = accountID
        guard expectedAccount != nil else { return }
        do {
            let data = try await authenticatedRequest(path: "/v1/account/session")
            let status = try JSONDecoder().decode(AccountStatus.self, from: data)
            guard version == generation, accountID == expectedAccount, status.accountID == expectedAccount else { return }
            premiumUntil = status.premiumActive ? status.premiumUntil.map(Date.init(timeIntervalSince1970:)) : nil
        } catch { if version == generation { premiumUntil = nil; errorMessage = message(for: error) } }
    }

    func syncSubscription(signedTransaction: String) async throws {
        struct Body: Encodable { let signed_transaction: String }
        let version = generation, expectedAccount = accountID
        let data = try await authenticatedRequest(path: "/v1/account/subscription", method: "POST",
                                                  body: try JSONEncoder().encode(Body(signed_transaction: signedTransaction)))
        let status = try JSONDecoder().decode(AccountStatus.self, from: data)
        guard version == generation, status.accountID == expectedAccount, accountID == expectedAccount else { throw AccountError.signInRequired }
        premiumUntil = status.premiumActive ? status.premiumUntil.map(Date.init(timeIntervalSince1970:)) : nil
    }

    @discardableResult
    func signOut() async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        let saved = session
        guard clearLocalSession() else { return false }
        if let saved, let transport {
            struct Body: Encodable { let refresh_token: String }
            do { _ = try await transport.request(path: "/v1/auth/logout", method: "POST", body: try JSONEncoder().encode(Body(refresh_token: saved.refreshToken)), accessToken: nil) }
            catch AccountError.http(401) { }
            catch { errorMessage = "You're signed out on this device. The service couldn't confirm remote session revocation; it will expire under the account policy." }
        }
        return true
    }

    @discardableResult
    func deleteAccount() async -> Bool {
        guard !isBusy, let deletedID = accountID else { return false }
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            _ = try await authenticatedRequest(path: "/v1/account", method: "DELETE")
            let cleared = clearLocalSession()
            lastDeletedAccountID = deletedID
            return cleared
        } catch { errorMessage = message(for: error); return false }
    }

    private func decodeSession(_ data: Data) throws -> AccountSession {
        let decoded = try JSONDecoder().decode(AccountSession.self, from: data)
        guard decoded.isValid(at: Date()) else { throw AccountError.invalidResponse }
        return decoded
    }
    private func adopt(_ next: AccountSession) throws {
        try vault.save(next)
        if accountID != next.accountID { premiumUntil = nil }
        session = next; accountID = next.accountID
    }
    @discardableResult
    private func clearLocalSession() -> Bool {
        generation += 1; refreshTask?.cancel(); refreshTask = nil; refreshID = nil
        session = nil; accountID = nil; premiumUntil = nil; challenge = nil; challengeReady = false; requestedChallengeID = nil
        do { try vault.remove(); return true }
        catch { errorMessage = AccountError.secureStorage.localizedDescription; return false }
    }
    private func message(for error: Error) -> String {
        (error as? AccountError)?.localizedDescription ?? "Your account couldn't connect. Please try again."
    }
    func reportCacheDeletionFailure() {
        errorMessage = "Your account was deleted, but its protected cache couldn't be removed from this iPhone. Delete the app to remove remaining local app data, or contact support."
    }
}
