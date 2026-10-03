import Foundation
import Testing
@testable import Omni

@Suite("Connect consent and reports")
@MainActor struct ConnectTests {
    @Test func reportsDecodeMissingPersonalityWithoutInventingScore() throws {
        let url = try #require(Bundle(for: ConnectBundleMarker.self).url(forResource: "ConnectReport", withExtension: "json"))
        let report = try JSONDecoder().decode(ConnectReport.self, from: Data(contentsOf: url))
        #expect(report.dimensions.count == 7)
        #expect(report.dimensions.last?.score == nil)
        #expect(report.recommended)
        #expect(report.shareText.contains("not a prediction"))
        #expect(!report.shareText.contains("1995-04-03"))
    }
    @Test func failedInvitationRemainsVisibleAfterRefresh() async {
        let store = ConnectStore()
        let account = AccountStore(transport: ConnectFixtureTransport(), vault: ConnectFixtureVault())
        await store.load(account)
        #expect(store.envelope?.revision == 2)
        await store.invite(kind: "dating", account: account)
        #expect(store.link == nil)
        #expect(store.error?.contains("Refresh") == true)
    }
    @Test func saveUsesCurrentRevisionAndDoesNotRequirePlus() async {
        let transport = ConnectFixtureTransport()
        let store = ConnectStore()
        let account = AccountStore(transport: transport, vault: ConnectFixtureVault())
        await store.load(account)
        var profile = ConnectProfile(); profile.name = "Synthetic Alex"
        #expect(await store.save(profile, account: account))
        let request = try? JSONSerialization.jsonObject(with: await transport.saved ?? Data()) as? [String: Any]
        #expect(request?["expected_revision"] as? Int == 2)
        #expect((request?["profile"] as? [String: Any])?["consent_version"] as? String == "connect-v1")
    }
}
private final class ConnectBundleMarker: NSObject {}
@MainActor private final class ConnectFixtureVault: AccountSessionPersisting {
    var value: AccountSession? = AccountSession(accountID: UUID(), accessToken: "synthetic-access", refreshToken: "synthetic-refresh", expiresAt: Date().addingTimeInterval(3600).timeIntervalSince1970)
    func load() throws -> AccountSession? { value }
    func save(_ session: AccountSession) throws { value = session }
    func remove() throws { value = nil }
}
private actor ConnectFixtureTransport: AccountTransport {
    var saved: Data?
    func request(path: String, method: String, body: Data?, accessToken: String?) async throws -> Data {
        guard accessToken == "synthetic-access" else { throw AccountError.signInRequired }
        if path == "/v1/connect/invitations" { throw AccountError.http(409) }
        if path == "/v1/connect/profile" { saved = body }
        return Data(#"{"revision":2,"profile":null,"invitations":[]}"#.utf8)
    }
}
