import Foundation

/// Joins concurrent delivery of the same signed event. A failed attempt can be retried,
/// and a later event for the same transaction (for example a refund) is never suppressed.
@MainActor
final class StoreDeliveryQueue {
    private struct Attempt {
        let id: UUID
        let representation: String
        let identityRevision: Int
        let task: Task<Bool, Never>
    }
    private var attempts: [UInt64: Attempt] = [:]

    func deliver(transactionID: UInt64, representation: String, identityRevision: Int,
                 isCurrent: @escaping @MainActor () -> Bool,
                 confirm: @escaping @MainActor () async throws -> Void,
                 finish: @escaping @MainActor () async -> Void) async -> Bool {
        guard isCurrent() else { return false }
        if let existing = attempts[transactionID] {
            let result = await existing.task.value
            guard isCurrent() else { return false }
            if existing.representation == representation && existing.identityRevision == identityRevision { return result }
            if attempts[transactionID]?.id == existing.id { attempts[transactionID] = nil }
            return await deliver(transactionID: transactionID, representation: representation, identityRevision: identityRevision,
                                 isCurrent: isCurrent, confirm: confirm, finish: finish)
        }
        let id = UUID()
        let task = Task { @MainActor in
            guard !Task.isCancelled, isCurrent() else { return false }
            do {
                try await confirm()
                guard !Task.isCancelled, isCurrent() else { return false }
                await finish()
                return true
            } catch { return false }
        }
        attempts[transactionID] = Attempt(id: id, representation: representation, identityRevision: identityRevision, task: task)
        let result = await task.value
        if attempts[transactionID]?.id == id { attempts[transactionID] = nil }
        return result
    }
}
