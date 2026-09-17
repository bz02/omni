import Foundation
import Security

struct MemoryReply: Sendable {
    let text: String
    let usedMemoryIDs: [UUID]
    var suggestions: [MemorySuggestion] = []
}

struct MemorySuggestion: Identifiable, Sendable {
    let id = UUID()
    let kind: String
    let text: String
    let sourceQuote: String
}

enum MemoryChatError: LocalizedError {
    case unavailable, consentRequired, expiredSession, subscriptionRequired, rateLimited, providerUnavailable, invalidResponse
    var errorDescription: String? {
        switch self {
        case .unavailable: "Conversations aren't connected in this build yet. You can still manage your memories."
        case .consentRequired: "Choose whether to allow the conversation service before sending."
        case .expiredSession: "Your conversation session has expired. Please connect your account again when account access is available."
        case .subscriptionRequired: "An active Plus subscription is required for conversations. Your saved records are still yours to manage."
        case .rateLimited: "You've sent several messages in a short time. Give it a moment, then try again."
        case .providerUnavailable: "The conversation service isn't available right now. Your message hasn't been added to saved history."
        case .invalidResponse: "The conversation couldn't be completed. Please try again."
        }
    }
}

/// An account integration must place its short-lived server-issued session here.
/// No provider secret or shared account token belongs in the app bundle.
enum MemorySessionVault {
    private static let service = "omni.memory.session"

    static func token(ownerID: UUID) -> String? {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["OMNI_MEMORY_SESSION_TOKEN"], !value.isEmpty { return value }
        #endif
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service,
                                   kSecAttrAccount as String: ownerID.uuidString,
                                   kSecReturnData as String: true,
                                   kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, let value = String(data: data, encoding: .utf8), !value.isEmpty else { return nil }
        return value
    }

    @discardableResult
    static func install(_ token: String, ownerID: UUID) -> Bool {
        guard !token.isEmpty, token.utf8.count <= 8192 else { return false }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service,
                                   kSecAttrAccount as String: ownerID.uuidString]
        let attributes: [String: Any] = [kSecValueData as String: Data(token.utf8),
                                        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        return SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess
    }

    static func remove(ownerID: UUID) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrService as String: service,
                       kSecAttrAccount as String: ownerID.uuidString] as CFDictionary)
    }
}

/// Redirects are rejected to keep account credentials and personal context on
/// the configured first-party host. URLSession uses no cookies or disk cache.
private final class MemoryRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

struct MemoryChatClient {
    var configuredEndpoint: URL?
    var sessionToken: String?
    var sessionConfiguration: URLSessionConfiguration?

    static var endpoint: URL? {
        #if DEBUG
        let configured = ProcessInfo.processInfo.environment["OMNI_MEMORY_API_URL"] ?? Bundle.main.object(forInfoDictionaryKey: "OMNI_MEMORY_API_URL") as? String
        #else
        let configured = Bundle.main.object(forInfoDictionaryKey: "OMNI_MEMORY_API_URL") as? String
        #endif
        guard let configured, let base = URL(string: configured), let host = base.host,
              base.user == nil, base.password == nil, base.query == nil, base.fragment == nil,
              !configured.contains("$("), !host.contains("example.") else { return nil }
        if base.scheme != "https" {
            #if DEBUG
            guard base.scheme == "http", ["127.0.0.1", "localhost", "::1"].contains(host) else { return nil }
            #else
            return nil
            #endif
        }
        return base.appendingPathComponent("v1/chat")
    }

    static func isAvailable(ownerID: UUID) -> Bool { endpoint != nil && MemorySessionVault.token(ownerID: ownerID) != nil }

    private struct ContextItem: Encodable { let id: String; let kind: String; let text: String }
    private struct HistoryItem: Encodable { let role: String; let content: String }
    private struct Payload: Encodable {
        let message: String
        let temporary: Bool
        let persist = false
        let local_context: [ContextItem]
        let local_history: [HistoryItem]
        let suggest_memories: Bool
    }
    private struct Response: Decodable {
        struct Message: Decodable { let role: String; let content: String }
        let message: Message
        let used_memory_ids: [String]
        let persisted: Bool
        struct Suggestion: Decodable { let kind: String; let text: String; let source_quote: String }
        let memory_suggestions: [Suggestion]?
    }

    func reply(to text: String, memories: [SavedMemory], history: [MemoryMessage], temporary: Bool,
               ownerID: UUID, consent: Bool, suggestMemories: Bool = false) async throws -> MemoryReply {
        guard consent else { throw MemoryChatError.consentRequired }
        guard let url = configuredEndpoint ?? Self.endpoint,
              let token = sessionToken ?? MemorySessionVault.token(ownerID: ownerID) else { throw MemoryChatError.unavailable }
        let selected = temporary ? [] : Array(memories.prefix(6))
        let payload = Payload(message: text, temporary: temporary,
                              local_context: selected.map { ContextItem(id: $0.id.uuidString, kind: $0.kind.rawValue, text: $0.text) },
                              local_history: history.suffix(8).map { HistoryItem(role: $0.role.rawValue, content: String($0.text.prefix(6000))) },
                              suggest_memories: suggestMemories && !temporary)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)
        let config = sessionConfiguration ?? URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 40
        config.timeoutIntervalForResource = 50
        config.httpCookieStorage = nil
        config.urlCache = nil
        let session = URLSession(configuration: config, delegate: MemoryRedirectPolicy(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw MemoryChatError.invalidResponse }
        switch http.statusCode {
        case 200: break
        case 401: throw MemoryChatError.expiredSession
        case 402, 403: throw MemoryChatError.subscriptionRequired
        case 429: throw MemoryChatError.rateLimited
        case 502, 503, 504: throw MemoryChatError.providerUnavailable
        default: throw MemoryChatError.invalidResponse
        }
        guard data.count <= 100_000,
              let result = try? JSONDecoder().decode(Response.self, from: data),
              result.message.role == "assistant", !result.persisted,
              !result.message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              result.message.content.count <= 12_000 else { throw MemoryChatError.invalidResponse }
        let allowedIDs = Set(selected.map(\.id))
        let used = result.used_memory_ids.compactMap(UUID.init(uuidString:)).filter { allowedIDs.contains($0) }
        let kinds = Set(MemoryKind.allCases.map(\.rawValue))
        let suggestions = (!temporary && suggestMemories ? result.memory_suggestions ?? [] : []).prefix(2).compactMap { item -> MemorySuggestion? in
            guard kinds.contains(item.kind), !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.text.count <= 1000, !item.source_quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  text.contains(item.source_quote) else { return nil }
            return MemorySuggestion(kind: item.kind, text: item.text, sourceQuote: item.source_quote)
        }
        return MemoryReply(text: result.message.content, usedMemoryIDs: Array(Set(used)), suggestions: suggestions)
    }
}
