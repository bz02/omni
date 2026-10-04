import Foundation
import Combine

struct DatingProfile: Codable, Equatable {
    var name = ""
    var birth_date = "1995-01-01"
    var birth_time: String?
    var birth_timezone: String?
    var birth_place: String?
    var birth_longitude: Double?
    var birth_fold: Int?
    var mbti = "unknown"
    var communication = "mix"
    var social = "mix"
    var value = "growth"
    var city = ""
    var gender = "unspecified"
    var seeking: [String] = ["woman", "man", "nonbinary"]
    var age_min = 18
    var age_max = 100
    var intention = "friendship"
    var bio = ""
    var visible = false
    var consent_version = "friends-v1"
}

struct DatingEnvelope: Decodable {
    let revision: Int
    let profile: DatingProfile?
    let status: String
    let discovery_enabled: Bool
    let photo_id: String?
}

struct DatingPairing: Decodable {
    let score: Int
    let signs: [String]
    let method: String
    let explanation: String
    let prompt: String
    let report: ConnectReport?
}

struct DatingCandidate: Decodable, Identifiable {
    let id: UUID
    let name: String
    let age: Int
    let city: String
    let bio: String
    let intention: String
    let pairing: DatingPairing
    let photo_id: String?
}

struct DatingMatch: Decodable, Identifiable {
    let id: UUID
    let profile: DatingCandidate
    let last_message: String?
    let updated_at: Double?
    let unread_count: Int?
    let pinned: Bool?
}

struct DatingMessage: Decodable, Identifiable {
    let id: UUID
    let text: String
    let mine: Bool
    let created_at: Double
    let sequence: Int?
    let seen: Bool?
    let reply_to: UUID?
    let reply_preview: String?
}

@MainActor
final class DatingStore: ObservableObject {
    @Published private(set) var envelope: DatingEnvelope?
    @Published private(set) var candidates: [DatingCandidate] = []
    @Published private(set) var sentLikes: [DatingCandidate] = []
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
                sentLikes = try await get(Discovery.self, "/v1/dating/likes", account).profiles
                matches = try await get(Matches.self, "/v1/dating/matches", account).matches
            } else { candidates = []; matches = []; sentLikes = [] }
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
            notice = result.matched ? "You both want to connect. Your conversation is ready below." : "Connection request saved. Chat opens when you both choose to connect."
            candidates.removeAll { $0.id == candidate.id }
            succeeded = true
        } catch { self.error = Self.message(error) }
        isBusy = false
        if succeeded { await load(account: account) }
    }

    func decide(_ candidate: DatingCandidate, unlike: Bool = false, account: AccountStore) async {
        guard !isBusy else { return }; isBusy = true; error = nil
        do {
            _ = try await account.authenticatedRequest(path: "/v1/dating/profiles/\(candidate.id.uuidString.lowercased())/\(unlike ? "like" : "pass")", method: unlike ? "DELETE" : "POST")
            notice = unlike ? "Request withdrawn. They will not be notified." : "Passed. This profile will stay out of your recommendations."
            isBusy = false; await load(account: account)
        } catch { self.error = Self.message(error); isBusy = false }
    }

    func photo(_ image: Data?, account: AccountStore) async -> Bool {
        guard !isBusy, let envelope else { return false }; isBusy = true; error = nil
        defer { isBusy = false }
        do {
            struct Upload: Encodable { let expected_revision: Int; let image: String }
            struct Remove: Encodable { let expected_revision: Int }
            let path = "/v1/dating/profile/photo"
            let data = try await account.authenticatedRequest(path: path, method: image == nil ? "DELETE" : "PUT", body: try image.map { try JSONEncoder().encode(Upload(expected_revision: envelope.revision, image: $0.base64EncodedString())) } ?? JSONEncoder().encode(Remove(expected_revision: envelope.revision)))
            self.envelope = try JSONDecoder().decode(DatingEnvelope.self, from: data)
            return true
        } catch { self.error = Self.message(error); return false }
    }

    func remove(account: AccountStore) async {
        guard !isBusy else { return }
        isBusy = true; error = nil
        defer { isBusy = false }
        do {
            let data = try await account.authenticatedRequest(path: "/v1/dating/profile", method: "DELETE")
            envelope = try JSONDecoder().decode(DatingEnvelope.self, from: data)
            candidates = []; matches = []; sentLikes = []; notice = "Your Connect profile, matches and conversations were deleted."
        } catch { self.error = Self.message(error) }
    }

    private func get<T: Decodable>(_ type: T.Type, _ path: String, _ account: AccountStore) async throws -> T {
        try JSONDecoder().decode(type, from: await account.authenticatedRequest(path: path))
    }

    static func message(_ error: Error) -> String {
        switch error {
        case AccountError.http(404): return "This profile or match is no longer available. Refresh to continue."
        case AccountError.http(409): return "These details changed or could not be saved. Close and refresh your profile before retrying. Contact support to correct a birth date."
        case AccountError.http(422): return "Check your details and age preferences. Connect is for adults 18 and older."
        case AccountError.http(503): return "Friend discovery isn't available right now. Please try again later."
        default: return error.localizedDescription
        }
    }
}

@MainActor
final class ConnectionChatStore: ObservableObject {
    @Published private(set) var messages: [DatingMessage] = []
    @Published private(set) var before: Int?
    @Published private(set) var busy = false
    @Published private(set) var readReceipts = false
    @Published private(set) var pinned = false
    @Published private(set) var peerReadThrough: Int?
    @Published private(set) var pending: Outgoing?
    @Published var draft = ""
    @Published var reply: DatingMessage?
    @Published var error: String?
    struct Outgoing: Encodable { let id: UUID; let text: String; let reply_to: UUID? }
    struct Page: Decodable {
        let messages: [DatingMessage]
        let next_before: Int?
        let read_receipts: Bool
        let pinned: Bool
        let peer_read_through: Int?
    }
    private var initialized = false
    static func path(_ id: UUID) -> String { "/v1/dating/matches/\(id.uuidString.lowercased())" }

    func load(_ id: UUID, account: AccountStore, older: Bool = false) async {
        guard !busy else { return }; busy = true
        defer { busy = false }
        do {
            struct Query: Encodable { let before: Int?; let limit = 30 }
            let data = try await account.authenticatedRequest(path: Self.path(id) + "/history", method: "POST", body: JSONEncoder().encode(Query(before: older ? before : nil)))
            let page = try JSONDecoder().decode(Page.self, from: data)
            if !older, let last = messages.last?.sequence, let first = page.messages.first?.sequence, first > last + 1 {
                messages = []; initialized = false
            }
            var merged = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) })
            for message in page.messages { merged[message.id] = message }
            messages = merged.values.sorted { ($0.sequence ?? 0) < ($1.sequence ?? 0) }
            if older || !initialized { before = page.next_before }
            initialized = true; readReceipts = page.read_receipts; pinned = page.pinned; peerReadThrough = page.peer_read_through; error = nil
            // The view calls this only while its conversation is active and visible.
            if !older, let sequence = page.messages.last?.sequence {
                struct Read: Encodable { let sequence: Int }
                _ = try await account.authenticatedRequest(path: Self.path(id) + "/read", method: "POST", body: JSONEncoder().encode(Read(sequence: sequence)))
            }
        } catch { handle(error) }
    }

    func send(_ id: UUID, account: AccountStore) async {
        guard !busy else { return }
        if pending == nil {
            let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            pending = Outgoing(id: UUID(), text: text, reply_to: reply?.id)
        }
        guard let pending else { return }; busy = true
        do {
            _ = try await account.authenticatedRequest(path: Self.path(id) + "/messages", method: "POST", body: JSONEncoder().encode(pending))
            if draft.trimmingCharacters(in: .whitespacesAndNewlines) == pending.text { draft = "" }
            self.pending = nil; reply = nil; error = nil
        } catch { handle(error) }
        busy = false
        if self.pending == nil { await load(id, account: account) }
    }

    func settings(_ id: UUID, account: AccountStore, pin: Bool? = nil, receipts: Bool? = nil) async {
        guard !busy else { return }; busy = true
        do {
            struct Settings: Encodable { let pinned: Bool?; let read_receipts: Bool? }
            _ = try await account.authenticatedRequest(path: Self.path(id) + "/settings", method: "PATCH", body: JSONEncoder().encode(Settings(pinned: pin, read_receipts: receipts)))
            if let pin { pinned = pin }; if let receipts { readReceipts = receipts }; error = nil
        } catch { handle(error) }
        busy = false
    }

    private func handle(_ error: Error) {
        if case AccountError.http(404) = error { messages = []; before = nil; pending = nil; reply = nil; draft = "" }
        self.error = DatingStore.message(error)
    }
}
