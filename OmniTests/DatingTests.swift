import Foundation
import Testing
@testable import Omni

@Suite("Dating requests stay inside the signed-in account", .serialized)
@MainActor
struct DatingTests {
    @Test func savedProfileUsesServerRevisionAndDoesNotTouchJournal() async throws {
        let transport = DatingFixtureTransport()
        let vault = DatingFixtureVault()
        let account = AccountStore(transport: transport, vault: vault, baseURL: nil)
        let store = DatingStore()
        await store.load(account: account)
        #expect(store.envelope?.revision == 4)
        var profile = DatingProfile()
        profile.name = "Test Adult"; profile.city = "New York"; profile.bio = "A synthetic profile for a local test."
        #expect(await store.save(profile, account: account))
        let body = try #require(await transport.saved)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["expected_revision"] as? Int == 4)
        #expect(store.envelope?.status == "pending")
        #expect(await transport.paths.allSatisfy { $0.hasPrefix("/v1/dating/") })
    }

    @Test func photoUsesCurrentRevisionAndDeletionHasNoQueryInPath() async throws {
        let transport = DatingFixtureTransport()
        let account = AccountStore(transport: transport, vault: DatingFixtureVault(), baseURL: nil)
        let store = DatingStore()
        await store.load(account: account)
        #expect(await store.photo(Data([1, 2, 3]), account: account))
        let uploaded = try #require(await transport.saved)
        let body = try #require(JSONSerialization.jsonObject(with: uploaded) as? [String: Any])
        #expect(body["expected_revision"] as? Int == 4)
        #expect(body["image"] as? String == "AQID")
        #expect(store.envelope?.photo_id == "synthetic-photo")
        #expect(await store.photo(nil, account: account))
        let removed = try #require(await transport.saved)
        let removeBody = try #require(JSONSerialization.jsonObject(with: removed) as? [String: Any])
        #expect(removeBody["expected_revision"] as? Int == 5)
        #expect(store.envelope?.photo_id == nil)
        #expect(await transport.paths.allSatisfy { !$0.contains("?") })
    }

    @Test func decodePrivateBirthFieldsAndOptionalPhoto() throws {
        let profile = try JSONDecoder().decode(DatingProfile.self, from: Data(#"{"name":"Demo","birth_date":"1995-04-03","birth_time":"13:25","birth_timezone":"America/New_York","birth_place":"New York","birth_longitude":-74,"mbti":"INFJ","communication":"mix","social":"quiet","value":"growth","city":"New York","gender":"man","seeking":["woman"],"age_min":25,"age_max":40,"intention":"long_term","bio":"A test introduction.","visible":true,"consent_version":"dating-v1"}"#.utf8))
        #expect(profile.birth_time == "13:25")
        #expect(profile.birth_longitude == -74)
        #expect(profile.mbti == "INFJ")
        #expect(profile.birth_fold == nil)
    }

    @Test func signedOutCannotLoadPrivateDatingProfiles() async {
        let transport = DatingFixtureTransport()
        let vault = DatingFixtureVault(); vault.value = nil
        let account = AccountStore(transport: transport, vault: vault, baseURL: nil)
        let store = DatingStore()
        await store.load(account: account)
        #expect(store.envelope == nil)
        #expect(store.error != nil)
        #expect(await transport.paths.isEmpty)
    }

    @Test func profileRemovalClearsVisibleMatchesOnlyAfterServerSuccess() async {
        let transport = DatingFixtureTransport()
        let account = AccountStore(transport: transport, vault: DatingFixtureVault(), baseURL: nil)
        let store = DatingStore()
        await store.load(account: account)
        await store.remove(account: account)
        #expect(store.envelope?.revision == 5)
        #expect(store.envelope?.profile == nil)
        #expect(store.candidates.isEmpty && store.matches.isEmpty)
    }
}

@MainActor private final class DatingFixtureVault: AccountSessionPersisting {
    var value: AccountSession? = AccountSession(accountID: UUID(), accessToken: "synthetic-access", refreshToken: "synthetic-refresh", expiresAt: Date().addingTimeInterval(3600).timeIntervalSince1970)
    func load() throws -> AccountSession? { value }
    func save(_ session: AccountSession) throws { value = session }
    func remove() throws { value = nil }
}

private actor DatingFixtureTransport: AccountTransport {
    var saved: Data?
    var paths: [String] = []
    func request(path: String, method: String, body: Data?, accessToken: String?) async throws -> Data {
        guard accessToken == "synthetic-access" else { throw AccountError.signInRequired }
        paths.append(path)
        switch (path, method) {
        case ("/v1/dating/profile/photo", "PUT"):
            saved = body
            return Data(#"{"revision":5,"profile":null,"status":"pending","discovery_enabled":true,"photo_id":"synthetic-photo"}"#.utf8)
        case ("/v1/dating/profile/photo", "DELETE"):
            saved = body
            return Data(#"{"revision":6,"profile":null,"status":"pending","discovery_enabled":true,"photo_id":null}"#.utf8)
        case ("/v1/dating/profile", "PUT"):
            saved = body
            return Data(#"{"revision":5,"profile":null,"status":"pending","discovery_enabled":true}"#.utf8)
        case ("/v1/dating/profile", "DELETE"):
            return Data(#"{"revision":5,"profile":null,"status":"draft","discovery_enabled":true}"#.utf8)
        case ("/v1/dating/profile", _):
            return Data(#"{"revision":4,"profile":null,"status":"draft","discovery_enabled":true}"#.utf8)
        case ("/v1/dating/likes", _): return Data(#"{"profiles":[]}"#.utf8)
        case ("/v1/dating/discover", _): return Data(#"{"profiles":[],"status":"profile_not_discoverable"}"#.utf8)
        case ("/v1/dating/matches", _): return Data(#"{"matches":[]}"#.utf8)
        default: throw AccountError.invalidResponse
        }
    }
}

@Suite("Connection chat delivery", .serialized)
@MainActor
struct ConnectionChatTests {
    @Test func retryKeepsIdentifierAndOlderPagesMerge() async throws {
        let transport = ConnectionChatFixture()
        let account = AccountStore(transport: transport, vault: DatingFixtureVault(), baseURL: nil)
        let chat = ConnectionChatStore(); let match = UUID()
        await chat.load(match, account: account)
        #expect(chat.messages.count == 1 && chat.before == 2)
        await chat.load(match, account: account, older: true)
        #expect(chat.messages.map { $0.sequence } == [1, 2])
        #expect(chat.before == nil)
        chat.reply = chat.messages.first; chat.draft = "A synthetic reply"
        await chat.send(match, account: account)
        #expect(chat.pending != nil && chat.error != nil)
        await chat.send(match, account: account)
        #expect(chat.pending == nil && chat.draft.isEmpty)
        let attempts = await transport.attempts
        #expect(attempts.count == 2)
        let first = try JSONSerialization.jsonObject(with: attempts[0]) as! NSDictionary
        let retry = try JSONSerialization.jsonObject(with: attempts[1]) as! NSDictionary
        #expect(first == retry)
        let body = try #require(JSONSerialization.jsonObject(with: attempts[0]) as? [String: Any])
        #expect(body["reply_to"] as? String == "00000000-0000-0000-0000-000000000001")
        await chat.settings(match, account: account, pin: true, receipts: true)
        #expect(chat.pinned && chat.readReceipts)
        await transport.block()
        await chat.load(match, account: account)
        #expect(chat.messages.isEmpty && chat.draft.isEmpty)
    }
}

private actor ConnectionChatFixture: AccountTransport {
    var attempts: [Data] = []
    var blocked = false
    func block() { blocked = true }
    func request(path: String, method: String, body: Data?, accessToken: String?) async throws -> Data {
        if blocked { throw AccountError.http(404) }
        if path.hasSuffix("/messages"), let body {
            attempts.append(body)
            if attempts.count == 1 { throw URLError(.networkConnectionLost) }
        }
        if path.hasSuffix("/history") {
            let query = try JSONSerialization.jsonObject(with: body!) as! [String: Any]
            let older = query["before"] as? Int != nil
            let sequence = older ? 1 : 2
            return Data("{\"messages\":[{\"id\":\"00000000-0000-0000-0000-00000000000\(sequence)\",\"text\":\"Hello\",\"mine\":false,\"created_at\":1,\"sequence\":\(sequence),\"seen\":false}],\"next_before\":\(older ? "null" : "2"),\"read_receipts\":false,\"pinned\":false}".utf8)
        }
        return Data("{}".utf8)
    }
}
