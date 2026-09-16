import Foundation
import Testing
@testable import Omni

@Suite("Account memory sync", .serialized)
@MainActor
struct MemorySyncTests {
    @Test("Account files are isolated from each other and from the guest archive")
    func accountIsolation() throws {
        let files = try SyncTestDirectory()
        defer { files.cleanUp() }
        let guest = MemoryStore(fileURL: files.directory.appendingPathComponent("guest.json"))
        #expect(guest.setSettings(MemorySettings(enabled: true), premium: true))
        #expect(guest.addMemory(kind: .profile, text: "A guest fact", premium: true) != nil)
        let firstID = UUID(), secondID = UUID()
        let first = MemoryStore.forAccount(firstID, directory: files.directory)
        let second = MemoryStore.forAccount(secondID, directory: files.directory)
        #expect(first.ownerID == firstID)
        #expect(first.memories.isEmpty)
        #expect(second.memories.isEmpty)
        #expect(first.setSettings(MemorySettings(enabled: true), premium: true))
        #expect(first.addMemory(kind: .profile, text: "A signed-in fact", premium: true) != nil)
        #expect(MemoryStore.forAccount(firstID, directory: files.directory).memories.count == 1)
        #expect(MemoryStore.forAccount(secondID, directory: files.directory).memories.isEmpty)
        try MemoryStore.removeAccountCache(firstID, directory: files.directory)
        #expect(MemoryStore.forAccount(firstID, directory: files.directory).memories.isEmpty)
        #expect(guest.memories.count == 1)
    }

    @Test("Cloud baselines survive restart and detect later edits without syncing device consent")
    func durableBaseline() throws {
        let files = try SyncTestDirectory()
        defer { files.cleanUp() }
        let owner = UUID()
        let store = MemoryStore.forAccount(owner, directory: files.directory)
        #expect(store.setSettings(MemorySettings(enabled: true), premium: true))
        let item = try #require(store.addMemory(kind: .profile, text: "Call me Avery.", premium: true))
        #expect(store.hasUnsyncedChanges)
        #expect(store.recordSuccessfulUpload(remoteRevision: 4, expectedLocalRevision: store.revision))
        #expect(!store.hasUnsyncedChanges)
        let reopened = MemoryStore.forAccount(owner, directory: files.directory)
        #expect(reopened.cloudRevision == 4)
        #expect(!reopened.hasUnsyncedChanges)
        #expect(!reopened.applyCloudSnapshot(MemoryCloudSnapshot(revision: 3, archive: nil), expectedLocalRevision: reopened.revision))
        #expect(!reopened.recordSuccessfulUpload(remoteRevision: 3, expectedLocalRevision: reopened.revision))
        #expect(reopened.cloudRevision == 4)
        var settings = reopened.settings
        settings.allowOnlineConversations = true
        #expect(reopened.setSettings(settings, premium: true))
        #expect(!reopened.hasUnsyncedChanges)
        #expect(reopened.updateMemory(id: item.id, kind: .profile, text: "Call me Ave now."))
        #expect(reopened.hasUnsyncedChanges)
        #expect(MemoryStore.forAccount(owner, directory: files.directory).hasUnsyncedChanges)
        let exported = String(decoding: try reopened.snapshotData(), as: UTF8.self)
        #expect(!exported.contains("allowOnlineConversations"))
        #expect(!exported.contains("localSync"))
    }

    @Test("A deliberate cloud download preserves sources and local online consent")
    func downloadRoundTrip() throws {
        let sourceFiles = try SyncTestDirectory(), destinationFiles = try SyncTestDirectory()
        defer { sourceFiles.cleanUp(); destinationFiles.cleanUp() }
        let owner = UUID()
        let source = MemoryStore.forAccount(owner, directory: sourceFiles.directory)
        #expect(source.setSettings(MemorySettings(enabled: true), premium: true))
        let user = MemoryMessage(role: .user, text: "I enjoy a quiet walk.")
        var conversation = MemoryConversation(title: "Date ideas", messages: [user])
        #expect(source.saveConversation(conversation, premium: true))
        let note = try #require(source.rememberMessage(conversationID: conversation.id, messageID: user.id, kind: .preference, premium: true))
        conversation.messages.append(MemoryMessage(role: .assistant, text: "What would be a comfortable place?", usedMemoryIDs: [note.id]))
        #expect(source.saveConversation(conversation, premium: true))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let transferred = try decoder.decode(MemoryArchive.self, from: source.snapshotData())
        let destination = MemoryStore.forAccount(owner, directory: destinationFiles.directory)
        #expect(destination.setSettings(MemorySettings(allowOnlineConversations: true), premium: true))
        #expect(destination.applyCloudSnapshot(MemoryCloudSnapshot(revision: 1, archive: transferred), expectedLocalRevision: destination.revision))
        #expect(destination.settings.allowOnlineConversations)
        #expect(destination.memories.first?.sourceMessageID == user.id)
        #expect(destination.conversations.first?.messages.last?.usedMemoryIDs == [note.id])
        #expect(try destination.snapshotData() == source.snapshotData())
        #expect(!destination.hasUnsyncedChanges)
    }

    @Test("Late uploads and downloads cannot mark newer local edits clean or replace them")
    func localCompareAndSwap() throws {
        let files = try SyncTestDirectory()
        defer { files.cleanUp() }
        let store = MemoryStore.forAccount(UUID(), directory: files.directory)
        #expect(store.setSettings(MemorySettings(enabled: true), premium: true))
        let item = try #require(store.addMemory(kind: .profile, text: "An earlier fact", premium: true))
        let downloaded = MemoryCloudSnapshot(revision: 2, archive: store.archive)
        let requestRevision = store.revision
        #expect(store.updateMemory(id: item.id, kind: .profile, text: "The latest fact"))
        #expect(!store.applyCloudSnapshot(downloaded, expectedLocalRevision: requestRevision))
        #expect(!store.recordSuccessfulUpload(remoteRevision: 3, expectedLocalRevision: requestRevision))
        #expect(store.memories.first?.text == "The latest fact")
        #expect(store.cloudRevision == nil)
        #expect(store.hasUnsyncedChanges)
    }

    @Test("Wrong owners, broken citations and unsupported schemas leave local data intact")
    func rejectInvalidSnapshots() throws {
        let files = try SyncTestDirectory()
        defer { files.cleanUp() }
        let store = MemoryStore.forAccount(UUID(), directory: files.directory)
        let original = try store.snapshotData()
        let foreign = MemoryArchive(ownerID: UUID())
        var unsupported = store.archive
        unsupported.version = 9
        var citation = store.archive
        citation.conversations = [MemoryConversation(title: "Invalid", messages: [MemoryMessage(role: .assistant, text: "An answer", usedMemoryIDs: [UUID()])])]
        for bad in [foreign, unsupported, citation] {
            #expect(!store.applyCloudSnapshot(MemoryCloudSnapshot(revision: 1, archive: bad), expectedLocalRevision: store.revision))
            #expect(try store.snapshotData() == original)
            #expect(store.cloudRevision == nil)
        }
    }

    @Test("Explicitly applying a cloud tombstone clears saved content and keeps its revision")
    func deletionTombstone() throws {
        let files = try SyncTestDirectory()
        defer { files.cleanUp() }
        let owner = UUID()
        let store = MemoryStore.forAccount(owner, directory: files.directory)
        #expect(store.setSettings(MemorySettings(enabled: true, allowOnlineConversations: true), premium: true))
        #expect(store.addMemory(kind: .profile, text: "A fact to forget", premium: true) != nil)
        #expect(store.recordSuccessfulUpload(remoteRevision: 1, expectedLocalRevision: store.revision))
        #expect(store.applyCloudSnapshot(MemoryCloudSnapshot(revision: 2, archive: nil), expectedLocalRevision: store.revision))
        #expect(store.memories.isEmpty)
        #expect(store.conversations.isEmpty)
        #expect(store.settings.allowOnlineConversations)
        #expect(!store.settings.enabled)
        let reopened = MemoryStore.forAccount(owner, directory: files.directory)
        #expect(reopened.cloudRevision == 2)
        #expect(!reopened.hasUnsyncedChanges)
    }

    @Test("Manual sync fetches a fresh token, sends CAS, and never retries conflicts")
    func manualTransport() async throws {
        let recorder = SyncRequestRecorder()
        let tokens = SyncTokenCounter()
        SyncURLProtocol.handler = { request in
            recorder.append(request)
            if request.httpMethod == "PUT" { return (409, Data("{\"detail\":\"Changed\"}".utf8)) }
            return (200, Data("{\"revision\":3,\"archive\":null}".utf8))
        }
        defer { SyncURLProtocol.handler = nil }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SyncURLProtocol.self]
        let client = MemorySyncClient(endpoint: URL(string: "https://sync.omni.test")!, tokenProvider: { await tokens.next() }, sessionConfiguration: configuration)
        #expect(try await client.pull(consent: true).revision == 3)
        let archive = Data("{\"version\":1}".utf8)
        do {
            _ = try await client.push(archiveData: archive, expectedRevision: 3, consent: true)
            Issue.record("A conflict must be surfaced.")
        } catch MemorySyncError.conflict { }
        let requests = recorder.requests
        #expect(requests.count == 2)
        #expect(requests[0].url?.path == "/v1/memory/snapshot")
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer token-1")
        #expect(requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer token-2")
        let payload = try #require(requests[1].httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["expected_revision"] as? Int == 3)
    }

    @Test("No consent means no token lookup and no request")
    func explicitConsent() async throws {
        let tokens = SyncTokenCounter()
        let client = MemorySyncClient(endpoint: URL(string: "https://sync.omni.test")!, tokenProvider: { await tokens.next() })
        do {
            _ = try await client.pull(consent: false)
            Issue.record("Sync must require consent.")
        } catch MemorySyncError.consentRequired { }
        #expect(await tokens.count == 0)
    }
}

private struct SyncTestDirectory {
    let directory: URL
    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("Omni-SyncTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    func cleanUp() { try? FileManager.default.removeItem(at: directory) }
}

private actor SyncTokenCounter {
    var count = 0
    func next() -> String { count += 1; return "token-\(count)" }
}

private final class SyncRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [URLRequest] = []
    func append(_ request: URLRequest) { lock.lock(); defer { lock.unlock() }; values.append(request) }
    var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return values }
}

private final class SyncURLProtocol: URLProtocol, @unchecked Sendable {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            var captured = request
            if captured.httpBody == nil, let stream = captured.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var body = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    body.append(contentsOf: buffer.prefix(count))
                }
                captured.httpBody = body
            }
            let (status, data) = try Self.handler!(captured)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}
