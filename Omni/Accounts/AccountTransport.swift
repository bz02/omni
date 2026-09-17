import Foundation
import Security
import CryptoKit

enum AccountConfiguration {
    static var baseURL: URL? {
        #if DEBUG
        let value = ProcessInfo.processInfo.environment["OMNI_MEMORY_API_URL"] ?? Bundle.main.object(forInfoDictionaryKey: "OMNI_MEMORY_API_URL") as? String
        #else
        let value = Bundle.main.object(forInfoDictionaryKey: "OMNI_MEMORY_API_URL") as? String
        #endif
        return validatedURL(value)
    }
    static func validatedURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value), let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              !value.contains("$("), !host.contains("example.") else { return nil }
        if url.scheme != "https" {
            #if DEBUG
            guard url.scheme == "http", ["localhost", "127.0.0.1", "::1"].contains(host) else { return nil }
            #else
            return nil
            #endif
        }
        return url
    }
    static func nonceHash(_ raw: String) -> String {
        SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

enum AccountError: Error, LocalizedError, Equatable {
    case unavailable, signInRequired, invalidResponse, expiredChallenge, secureStorage, refreshUncertain, cancelled, http(Int)
    var errorDescription: String? {
        switch self {
        case .unavailable: "Accounts aren't connected in this build yet. Your local journal remains available."
        case .signInRequired: "Please sign in with Apple to connect your Omni account."
        case .invalidResponse: "The account service returned an unexpected response. Please try again."
        case .expiredChallenge: "Your sign-in request expired. Prepare a new request and try again."
        case .secureStorage: "Your account couldn't be saved securely on this device. Please try again."
        case .refreshUncertain: "Your session couldn't be renewed safely. Please sign in with Apple again."
        case .cancelled: "Sign-in was cancelled."
        case .http(401): "Your session has expired. Please sign in with Apple again."
        case .http(403): "This purchase is associated with a different Omni account. Sign in to that account to continue."
        case .http(429): "Please wait a moment before trying again."
        case .http(503): "The account service is unavailable right now. Please try again later."
        case .http: "Your account request couldn't be completed. Please try again."
        }
    }
}

struct AccountChallenge: Decodable, Sendable {
    let challengeID: String
    let nonce: String
    let expiresAt: Double
    enum CodingKeys: String, CodingKey { case challengeID = "challenge_id", nonce, expiresAt = "expires_at" }
}

struct AccountSession: Codable, Equatable, Sendable {
    let accountID: UUID
    let accessToken: String
    let refreshToken: String
    let expiresAt: Double
    enum CodingKeys: String, CodingKey {
        case accountID = "account_id", accessToken = "access_token", refreshToken = "refresh_token", expiresAt = "expires_at"
    }
    func isValid(at now: Date) -> Bool {
        !accessToken.isEmpty && accessToken.utf8.count <= 32768 && !refreshToken.isEmpty && refreshToken.utf8.count <= 8192 &&
        expiresAt.isFinite && expiresAt > now.timeIntervalSince1970 && expiresAt < now.addingTimeInterval(172800).timeIntervalSince1970
    }
}

struct AccountStatus: Decodable, Sendable {
    let accountID: UUID
    let premiumUntil: Double?
    let premiumActive: Bool
    enum CodingKeys: String, CodingKey { case accountID = "account_id", premiumUntil = "premium_until", premiumActive = "premium_active" }
}

protocol AccountTransport: Sendable {
    func request(path: String, method: String, body: Data?, accessToken: String?) async throws -> Data
}

private final class AccountRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

struct AccountHTTPTransport: AccountTransport {
    let baseURL: URL
    func request(path: String, method: String, body: Data?, accessToken: String?) async throws -> Data {
        guard AccountConfiguration.validatedURL(baseURL.absoluteString) != nil,
              path.hasPrefix("/v1/"), !path.contains(".."), !path.contains("?"), !path.contains("#") else { throw AccountError.unavailable }
        try Task.checkCancellation()
        var request = URLRequest(url: baseURL.appendingPathComponent(String(path.dropFirst())))
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken { request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization") }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 35
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: AccountRedirectPolicy(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw AccountError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw AccountError.http(http.statusCode) }
        guard data.count <= 100_000 else { throw AccountError.invalidResponse }
        return data
    }
}

@MainActor
protocol AccountSessionPersisting {
    func load() throws -> AccountSession?
    func save(_ session: AccountSession) throws
    func remove() throws
}

struct AccountKeychainVault: AccountSessionPersisting {
    var namespace: String = AccountConfiguration.baseURL?.absoluteString ?? "unconfigured"
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "omni.account.session.v1", kSecAttrAccount as String: AccountConfiguration.nonceHash(namespace)]
    }
    func load() throws -> AccountSession? {
        var read = query
        read[kSecReturnData as String] = true
        read[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data, let session = try? JSONDecoder().decode(AccountSession.self, from: data) else { throw AccountError.secureStorage }
        return session
    }
    func save(_ session: AccountSession) throws {
        let attributes: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(session),
                                         kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound,
              SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess else { throw AccountError.secureStorage }
    }
    func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw AccountError.secureStorage }
    }
}
