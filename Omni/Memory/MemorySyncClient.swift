import Foundation

struct MemoryCloudSnapshot: Decodable {
    let revision: Int
    let archive: MemoryArchive?
}

enum MemorySyncError: LocalizedError {
    case consentRequired, unavailable, expiredSession, subscriptionRequired, conflict, invalidResponse, serverUnavailable

    var errorDescription: String? {
        switch self {
        case .consentRequired: "Choose whether to sync with your account before continuing."
        case .unavailable: "Cloud memory isn't connected in this build."
        case .expiredSession: "Sign in again before syncing memory."
        case .subscriptionRequired: "Plus is required to upload new memories or conversations. Existing cloud records remain available to manage."
        case .conflict: "Cloud memory changed on another device. Review it before choosing which version to keep."
        case .invalidResponse: "The cloud memory response couldn't be verified. Your local data hasn't been replaced."
        case .serverUnavailable: "Cloud memory couldn't connect. Your local data is still here."
        }
    }
}

private final class MemorySyncRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

/// Manual operations only. The account integration supplies a freshly refreshed access token.
struct MemorySyncClient {
    let endpoint: URL
    let tokenProvider: @Sendable () async throws -> String
    var sessionConfiguration: URLSessionConfiguration?

    func pull(consent: Bool) async throws -> MemoryCloudSnapshot {
        try await request(method: "GET", body: nil, consent: consent)
    }

    func push(archiveData: Data, expectedRevision: Int, consent: Bool) async throws -> MemoryCloudSnapshot {
        guard expectedRevision >= 0, archiveData.count <= 1_900_000,
              let archive = try JSONSerialization.jsonObject(with: archiveData) as? [String: Any] else { throw MemorySyncError.invalidResponse }
        let body = try JSONSerialization.data(withJSONObject: ["expected_revision": expectedRevision, "archive": archive])
        return try await request(method: "PUT", body: body, consent: consent)
    }

    func delete(expectedRevision: Int, consent: Bool) async throws -> MemoryCloudSnapshot {
        guard expectedRevision >= 0 else { throw MemorySyncError.invalidResponse }
        let body = try JSONSerialization.data(withJSONObject: ["expected_revision": expectedRevision])
        return try await request(method: "DELETE", body: body, consent: consent)
    }

    private func request(method: String, body: Data?, consent: Bool) async throws -> MemoryCloudSnapshot {
        guard consent else { throw MemorySyncError.consentRequired }
        guard Self.validEndpoint(endpoint) else { throw MemorySyncError.unavailable }
        try Task.checkCancellation()
        let token = try await tokenProvider()
        guard !token.isEmpty, token.utf8.count <= 8192 else { throw MemorySyncError.expiredSession }
        try Task.checkCancellation()
        var request = URLRequest(url: endpoint.appendingPathComponent("v1/memory/snapshot"))
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let configuration = sessionConfiguration ?? .ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 45
        let session = URLSession(configuration: configuration, delegate: MemorySyncRedirectPolicy(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw MemorySyncError.invalidResponse }
        switch response.statusCode {
        case 200: break
        case 401: throw MemorySyncError.expiredSession
        case 402, 403: throw MemorySyncError.subscriptionRequired
        case 409: throw MemorySyncError.conflict
        case 500...599: throw MemorySyncError.serverUnavailable
        default: throw MemorySyncError.invalidResponse
        }
        guard data.count <= 2_097_152 else { throw MemorySyncError.invalidResponse }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let standard = ISO8601DateFormatter()
            if let date = standard.date(from: value) { return date }
            standard.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = standard.date(from: value) else { throw MemorySyncError.invalidResponse }
            return date
        }
        guard let result = try? decoder.decode(MemoryCloudSnapshot.self, from: data), result.revision >= 0 else { throw MemorySyncError.invalidResponse }
        return result
    }

    private static func validEndpoint(_ url: URL) -> Bool {
        guard let host = url.host, !host.isEmpty, url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return false }
        if url.scheme == "https" { return true }
        #if DEBUG
        return url.scheme == "http" && ["127.0.0.1", "localhost", "::1"].contains(host)
        #else
        return false
        #endif
    }
}
