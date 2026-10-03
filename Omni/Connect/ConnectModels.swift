import Foundation
import Combine

struct ConnectProfile: Codable, Equatable {
    var name = ""
    var birth_date = "1995-01-01"
    var mbti = "unknown"
    var five_element = "auto"
    var intention = "long_term"
    var communication = "mix"
    var social = "mix"
    var value = "growth"
    var consent_version = "connect-v1"
}
struct ConnectDimension: Codable, Identifiable {
    let key: String
    let title: String
    let score: Int?
    let weight: Int
    let explanation: String
    let prompt: String
    var id: String { key }
}
struct ConnectReport: Codable {
    let method: String
    let score: Int
    let recommendation: String
    let recommended: Bool
    let names: [String]
    let kind: String
    let dimensions: [ConnectDimension]
    let strengths: [String]
    let friction: [String]
    let date_idea: String
    let disclaimer: String
    var shareText: String {
        "Omni · \(names.joined(separator: " + "))\n\(score)/100 conversation fit · \(recommendation)\n\n" + strengths.joined(separator: "\n") + "\n\nA creative reflection index, not a prediction of relationship success."
    }
}
struct ConnectInvitation: Codable, Identifiable {
    let id: UUID
    let kind: String
    let expires_at: Double
    let created_at: Double
    let status: String
    let report: ConnectReport?
}
struct ConnectEnvelope: Codable {
    let revision: Int
    let profile: ConnectProfile?
    let invitations: [ConnectInvitation]
}
struct ConnectLink: Identifiable {
    let id: UUID
    let url: URL
}
@MainActor final class ConnectStore: ObservableObject {
    @Published private(set) var envelope: ConnectEnvelope?
    @Published private(set) var busy = false
    @Published var error: String?
    @Published var link: ConnectLink?
    var recommendations: [ConnectInvitation] { (envelope?.invitations ?? []).filter { $0.report?.recommended == true } }
    func load(_ account: AccountStore) async {
        guard !busy, account.isSignedIn else { return }
        busy = true; error = nil; defer { busy = false }
        do { envelope = try JSONDecoder().decode(ConnectEnvelope.self, from: await account.authenticatedRequest(path: "/v1/connect")) }
        catch { self.error = Self.message(error) }
    }
    func save(_ profile: ConnectProfile, account: AccountStore) async -> Bool {
        guard !busy, let envelope else { return false }
        busy = true; error = nil; defer { busy = false }
        struct Body: Encodable { let expected_revision: Int; let profile: ConnectProfile }
        do {
            let data = try await account.authenticatedRequest(path: "/v1/connect/profile", method: "PUT", body: JSONEncoder().encode(Body(expected_revision: envelope.revision, profile: profile)))
            self.envelope = try JSONDecoder().decode(ConnectEnvelope.self, from: data)
            return true
        } catch { self.error = Self.message(error); return false }
    }
    func invite(kind: String, account: AccountStore) async {
        guard !busy else { return }
        busy = true; error = nil; link = nil
        struct Body: Encodable { let id: UUID; let kind: String }
        struct Result: Decodable { let id: UUID; let token: String }
        do {
            let data = try await account.authenticatedRequest(path: "/v1/connect/invitations", method: "POST", body: JSONEncoder().encode(Body(id: UUID(), kind: kind)))
            let result = try JSONDecoder().decode(Result.self, from: data)
            guard let base = AccountConfiguration.baseURL, var url = URLComponents(url: base.appendingPathComponent("connect"), resolvingAgainstBaseURL: false) else { throw AccountError.unavailable }
            url.fragment = "invite=\(result.token)"
            guard let target = url.url else { throw AccountError.invalidResponse }
            link = ConnectLink(id: result.id, url: target)
        } catch { self.error = Self.message(error) }
        busy = false
        let failure = error; await load(account); if let failure { error = failure }
    }
    func remove(_ invitation: ConnectInvitation, account: AccountStore) async {
        guard !busy else { return }
        busy = true; error = nil
        do { _ = try await account.authenticatedRequest(path: "/v1/connect/invitations/\(invitation.id.uuidString.lowercased())", method: "DELETE") }
        catch { self.error = Self.message(error) }
        busy = false
        // Do not clear deletion errors with a successful reload.
        let failure = error; await load(account); if let failure { error = failure }
    }
    func erase(_ account: AccountStore) async {
        guard !busy else { return }; busy = true; error = nil; defer { busy = false }
        do { envelope = try JSONDecoder().decode(ConnectEnvelope.self, from: await account.authenticatedRequest(path: "/v1/connect", method: "DELETE")); link = nil }
        catch { self.error = Self.message(error) }
    }
    static func message(_ error: Error) -> String {
        switch error {
        case AccountError.http(409): return "Your profile changed or this invite already exists. Refresh before trying again."
        case AccountError.http(422): return "Check the birth date and profile fields. Connect is for adults 18 to 100."
        case AccountError.http(404), AccountError.http(503): return "Connect is temporarily unavailable. Your existing records are safe; please try again later."
        case AccountError.http(429): return "Please wait before trying again, or remove an old invitation if you have reached 100."
        default: return error.localizedDescription
        }
    }
}
