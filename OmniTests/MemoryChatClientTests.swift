import Foundation
import Testing
@testable import Omni

/// Real URLSession encoding/decoding against an in-process transport, never a live model.
@Suite("Memory conversation transport", .serialized)
struct MemoryChatClientTests {
    @Test("Native requests contain bounded context and never request server persistence")
    func requestContract() async throws {
        let captured = CapturedMemoryRequest()
        MemoryURLProtocol.handler = { request in
            captured.request = request
            return (200, Self.response())
        }
        let memories = (0..<8).map { SavedMemory(kind: .preference, text: "Walking preference \($0)") }
        let history = (0..<12).map { MemoryMessage(role: $0.isMultiple(of: 2) ? .user : .assistant, text: "Turn \($0)") }
        let reply = try await client().reply(to: "What about walking?", memories: memories, history: history, temporary: false, ownerID: UUID(), consent: true)
        #expect(reply.text == "A synthetic test reply.")
        let request = try #require(captured.request)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-session")
        let body = try #require(try JSONSerialization.jsonObject(with: Self.body(request)) as? [String: Any])
        #expect(body["persist"] as? Bool == false)
        #expect((body["local_context"] as? [[String: Any]])?.count == 6)
        let turns = try #require(body["local_history"] as? [[String: Any]])
        #expect(turns.count == 8)
        #expect(turns.first?["content"] as? String == "Turn 4")
        #expect(body["user_id"] == nil)
        #expect(body["premium"] == nil)
    }

    @Test("Temporary mode excludes saved memories and suggestions, with only current in-memory turns")
    func temporaryContract() async throws {
        let captured = CapturedMemoryRequest()
        MemoryURLProtocol.handler = { request in captured.request = request; return (200, Self.response()) }
        _ = try await client().reply(to: "Today", memories: [SavedMemory(kind: .profile, text: "Private saved profile")],
                                    history: [MemoryMessage(role: .user, text: "This temporary chat only")],
                                    temporary: true, ownerID: UUID(), consent: true, suggestMemories: true)
        let request = try #require(captured.request)
        let data = try Self.body(request)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["temporary"] as? Bool == true)
        #expect(body["suggest_memories"] as? Bool == false)
        #expect((body["local_context"] as? [Any])?.isEmpty == true)
        #expect((body["local_history"] as? [Any])?.count == 1)
        #expect(!String(decoding: data, as: UTF8.self).contains("Private saved profile"))
    }

    @Test("No consent means no HTTP request")
    func consentRequired() async throws {
        let captured = CapturedMemoryRequest()
        MemoryURLProtocol.handler = { request in captured.request = request; return (200, Self.response()) }
        await #expect(throws: MemoryChatError.self) {
            _ = try await client().reply(to: "Don't send", memories: [], history: [], temporary: false, ownerID: UUID(), consent: false)
        }
        #expect(captured.request == nil)
    }

    @Test("Only supplied memory IDs and current-message-grounded suggestions are accepted")
    func responseBoundaries() async throws {
        let selected = SavedMemory(kind: .preference, text: "I like morning walks")
        let foreign = UUID()
        let payload: [String: Any] = ["message": ["role": "assistant", "content": "A synthetic test reply."], "persisted": false,
                                     "used_memory_ids": [selected.id.uuidString, foreign.uuidString],
                                     "memory_suggestions": [
                                        ["kind": "preference", "text": "I like morning walks", "source_quote": "I like morning walks"],
                                        ["kind": "profile", "text": "An invented fact", "source_quote": "Something the user never said"]]]
        MemoryURLProtocol.handler = { _ in (200, try JSONSerialization.data(withJSONObject: payload)) }
        let result = try await client().reply(to: "I like morning walks", memories: [selected], history: [], temporary: false, ownerID: UUID(), consent: true, suggestMemories: true)
        #expect(result.usedMemoryIDs == [selected.id])
        #expect(result.suggestions.count == 1)
        #expect(result.suggestions.first?.text == "I like morning walks")
    }

    @Test("Unexpected persistence or malformed replies fail without presenting a successful chat")
    func persistenceMismatch() async throws {
        MemoryURLProtocol.handler = { _ in (200, Self.response(persisted: true)) }
        await #expect(throws: MemoryChatError.self) {
            _ = try await client().reply(to: "Hello", memories: [], history: [], temporary: false, ownerID: UUID(), consent: true)
        }
        MemoryURLProtocol.handler = { _ in (200, Data("[]".utf8)) }
        await #expect(throws: MemoryChatError.self) {
            _ = try await client().reply(to: "Hello", memories: [], history: [], temporary: false, ownerID: UUID(), consent: true)
        }
    }

    @Test("Authentication, paid access, rate and provider failures surface actionable errors")
    func failedRequests() async throws {
        for status in [401, 403, 429, 503] {
            MemoryURLProtocol.handler = { _ in (status, Data("{}".utf8)) }
            do {
                _ = try await client().reply(to: "Hello", memories: [], history: [], temporary: false, ownerID: UUID(), consent: true)
                Issue.record("An HTTP failure unexpectedly produced a reply")
            } catch let error as MemoryChatError {
                switch (status, error) {
                case (401, .expiredSession), (403, .subscriptionRequired), (429, .rateLimited), (503, .providerUnavailable): break
                default: Issue.record("Unexpected error mapping")
                }
            }
        }
    }

    private func client() -> MemoryChatClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MemoryURLProtocol.self]
        return MemoryChatClient(configuredEndpoint: URL(string: "https://memory.invalid/v1/chat")!, sessionToken: "synthetic-session", sessionConfiguration: config)
    }
    private static func response(persisted: Bool = false) -> Data {
        try! JSONSerialization.data(withJSONObject: ["message": ["role": "assistant", "content": "A synthetic test reply."], "used_memory_ids": [], "persisted": persisted])
    }
    private static func body(_ request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { throw CocoaError(.fileReadUnknown) }
        stream.open(); defer { stream.close() }
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { throw CocoaError(.fileReadUnknown) }
            if count == 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}

private final class CapturedMemoryRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: URLRequest?
    var request: URLRequest? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

private final class MemoryURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var stored: ((URLRequest) throws -> (Int, Data))?
    static var handler: ((URLRequest) throws -> (Int, Data))? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "memory.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
