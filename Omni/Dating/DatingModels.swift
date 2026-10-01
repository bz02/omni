import Foundation
import Combine

struct DatingProfile: Codable, Equatable {
    var name = ""
    var birth_date = "1995-01-01"
    var city = ""
    var gender = ""
    var seeking: [String] = []
    var age_min = 18
    var age_max = 100
    var intention = "long_term"
    var bio = ""
    var visible = false
    var consent_version = "dating-v1"
}

struct DatingEnvelope: Decodable {
    let revision: Int
    let profile: DatingProfile?
    let status: String
    let discovery_enabled: Bool
}

struct DatingPairing: Decodable {
    let score: Int
    let signs: [String]
    let method: String
    let explanation: String
    let prompt: String
}

struct DatingCandidate: Decodable, Identifiable {
    let id: UUID
    let name: String
    let age: Int
    let city: String
    let bio: String
    let intention: String
    let pairing: DatingPairing
}

struct DatingMatch: Decodable, Identifiable {
    let id: UUID
    let profile: DatingCandidate
}

struct DatingMessage: Decodable, Identifiable {
    let id: UUID
    let text: String
    let mine: Bool
    let created_at: Double
}

@MainActor
final class DatingStore: ObservableObject {
    @Published private(set) var envelope: DatingEnvelope?
    @Published private(set) var candidates: [DatingCandidate] = []
    @Published private(set) var matches: [DatingMatch] = []
    @Published private(set) var isBusy = false
    @Published var error: String?
    @Published var notice: String?

    func load(account: AccountStore) async {
        guard !isBusy else { return }
        isBusy = true; error = nil
        defer { isBusy = false }
        do {
            envelope = try await get(DatingEnvelope.self, "/v1/dating/profile", account)
            if envelope?.discovery_enabled == true {
                struct Discovery: Decodable { let profiles: [DatingCandidate] }
                struct Matches: Decodable { let matches: [DatingMatch] }
                candidates = try await get(Discovery.self, "/v1/dating/discover", account).profiles
                matches = try await get(Matches.self, "/v1/dating/matches", account).matches
            } else { candidates = []; matches = [] }
        } catch { self.error = Self.message(error) }
    }

    func save(_ profile: DatingProfile, account: AccountStore) async -> Bool {
        guard let envelope, !isBusy else { return false }
        isBusy = true; error = nil
        defer { isBusy = false }
        do {
            struct Body: Encodable { let expected_revision: Int; let profile: DatingProfile }
            let data = try await account.authenticatedRequest(path: "/v1/dating/profile", method: "PUT", body: JSONEncoder().encode(Body(expected_revision: envelope.revision, profile: profile)))
            self.envelope = try JSONDecoder().decode(DatingEnvelope.self, from: data)
            candidates = []
            notice = profile.visible ? "Profile saved. New and edited public details are reviewed before discovery." : "Your profile is hidden from discovery."
            return true
        } catch { self.error = Self.message(error); return false }
    }

    func like(_ candidate: DatingCandidate, account: AccountStore) async {
        guard !isBusy else { return }
        isBusy = true; error = nil
        var succeeded = false
        do {
            struct Result: Decodable { let matched: Bool }
            let data = try await account.authenticatedRequest(path: "/v1/dating/profiles/\(candidate.id.uuidString.lowercased())/like", method: "POST")
            let result = try JSONDecoder().decode(Result.self, from: data)
            notice = result.matched ? "It's a mutual match. Your conversation is ready below." : "Like saved. You can chat if you both like each other."
            candidates.removeAll { $0.id == candidate.id }
            succeeded = true
        } catch { self.error = Self.message(error) }
        isBusy = false
        if succeeded { await load(account: account) }
    }

    func remove(account: AccountStore) async {
        guard !isBusy else { return }
        isBusy = true; error = nil
        defer { isBusy = false }
        do {
            let data = try await account.authenticatedRequest(path: "/v1/dating/profile", method: "DELETE")
            envelope = try JSONDecoder().decode(DatingEnvelope.self, from: data)
            candidates = []; matches = []; notice = "Your dating profile, matches and conversations were deleted."
        } catch { self.error = Self.message(error) }
    }

    private func get<T: Decodable>(_ type: T.Type, _ path: String, _ account: AccountStore) async throws -> T {
        try JSONDecoder().decode(type, from: await account.authenticatedRequest(path: path))
    }

    static func message(_ error: Error) -> String {
        switch error {
        case AccountError.http(404): return "This profile or match is no longer available. Refresh to continue."
        case AccountError.http(409): return "These details changed or could not be saved. Close and refresh your profile before retrying. Contact support to correct a birth date."
        case AccountError.http(422): return "Check your details and age preferences. Dating is for adults 18 and older."
        case AccountError.http(503): return "Dating isn't available right now. Please try again later."
        default: return error.localizedDescription
        }
    }
}
