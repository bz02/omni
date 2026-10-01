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
        case ("/v1/dating/profile", "PUT"):
            saved = body
            return Data(#"{"revision":5,"profile":null,"status":"pending","discovery_enabled":true}"#.utf8)
        case ("/v1/dating/profile", "DELETE"):
            return Data(#"{"revision":5,"profile":null,"status":"draft","discovery_enabled":true}"#.utf8)
        case ("/v1/dating/profile", _):
            return Data(#"{"revision":4,"profile":null,"status":"draft","discovery_enabled":true}"#.utf8)
        case ("/v1/dating/discover", _): return Data(#"{"profiles":[],"status":"profile_not_discoverable"}"#.utf8)
        case ("/v1/dating/matches", _): return Data(#"{"matches":[]}"#.utf8)
        default: throw AccountError.invalidResponse
        }
    }
}
