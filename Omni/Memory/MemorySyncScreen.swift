import SwiftUI
import UniformTypeIdentifiers

/// Synchronization is an explicit user action. A server revision is never
/// overwritten until we have compared it with the last acknowledged copy.
struct MemorySyncScreen: View {
    @EnvironmentObject private var memory: MemoryStore
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var consent = false
    @State private var busy = false
    @State private var status: String?
    @State private var pending: Task<Void, Never>?
    @State private var conflict: MemoryCloudSnapshot?
    @State private var conflictLocalRevision: Int?
    @State private var replaceLocal = false
    @State private var replaceCloud = false
    @State private var deleteCloud = false
    @State private var export = false
    @State private var document = JournalExport(data: Data())

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeading(eyebrow: "PICK UP ON ANOTHER IPHONE", title: "The details\nyou choose to keep.", subtitle: "Sync saved memories and conversation history for this Omni account.")
                    OmniCard(color: OmniTheme.sage) {
                        Text("\(memory.memories.count) memories · \(memory.conversations.count) conversations").font(.headline)
                        Text(memory.cloudRevision == nil ? "This iPhone hasn't synced this account yet." : (memory.hasUnsyncedChanges ? "You have changes on this iPhone to sync." : "This iPhone matches its last completed sync. Another device may have newer changes.")).font(.system(size: 13)).lineSpacing(4)
                    }
                    Text("Sync sends this account's saved memories, saved conversations and memory/history settings to Omni's server. On your other iPhone, sign in to the same account and choose Sync now. Your local journal and unsigned-in memories are not included.").font(.system(size: 14)).lineSpacing(4)
                    Text("Sync runs only when you choose it here. Temporary conversations are never included. Permission to send chats to OpenAI stays separate on each device; syncing does not switch it on.").font(.system(size: 13)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                    Toggle("Allow this sync session", isOn: $consent).disabled(busy).accessibilityIdentifier("sync.consent")
                    OmniButton(title: busy ? "Checking your copies…" : "Sync now", icon: "arrow.triangle.2.circlepath") { synchronize() }
                        .disabled(!consent || busy || !account.isSignedIn || memory.recoveryRequired)
                        .accessibilityIdentifier("sync.now")
                    if let status { Text(status).font(.system(size: 13)).foregroundStyle(OmniTheme.muted).accessibilityIdentifier("sync.status") }
                    if let conflict {
                        OmniCard(color: OmniTheme.peach.opacity(0.6)) {
                            Eyebrow(text: "TWO DIFFERENT COPIES")
                            Text("Choose which copy to keep.").font(OmniTheme.title(23))
                            Text("Cloud: \(conflict.archive?.memories.count ?? 0) memories and \(conflict.archive?.conversations.count ?? 0) conversations.\nThis iPhone: \(memory.memories.count) memories and \(memory.conversations.count) conversations.").font(.system(size: 13)).lineSpacing(4)
                            if conflict.archive == nil { Text("The cloud copy is empty or has been deleted.").font(.caption) }
                            Text("There is no automatic merge. Export either copy before replacing it if you want a backup.").font(.caption)
                            Button("Export cloud copy") { prepareCloudExport(conflict) }.font(.subheadline)
                            Button("Use cloud copy on this iPhone") { replaceLocal = true }.font(.headline)
                            Button("Use this iPhone's copy in the cloud") { replaceCloud = true }.font(.headline)
                        }.disabled(busy || !consent).accessibilityIdentifier("sync.conflict")
                    }
                    Button { prepareLocalExport() } label: { Label("Export this iPhone's memory", systemImage: "square.and.arrow.up") }.font(.subheadline)
                    if memory.cloudRevision != nil {
                        Button("Delete cloud copy", role: .destructive) { deleteCloud = true }.font(.subheadline).disabled(busy || !consent)
                    }
                    Text("Deleting only the cloud copy keeps this iPhone's records. Other devices learn about the deletion when they sync. To remove the entire account, use Your Omni account → Delete account. Your Apple subscription is managed separately.").font(.caption).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                }.padding(24)
            }.background(OmniTheme.paper)
                .navigationTitle("Account memory").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
                .fileExporter(isPresented: $export, document: document, contentType: .json, defaultFilename: "Omni-memory-backup") { result in
                    if case .failure = result { status = "The backup couldn't be exported. Your copies have not been replaced." }
                }
                .confirmationDialog("Replace this iPhone's account memories and history with the cloud copy? Local changes will be discarded. Export a backup first if you want to keep them.", isPresented: $replaceLocal, titleVisibility: .visible) {
                    Button("Replace this iPhone's copy", role: .destructive) { useCloudCopy() }
                }
                .confirmationDialog("Replace the cloud copy with this iPhone's account memories and history? Changes made on another device may be removed. Export the cloud copy first if you want to keep them.", isPresented: $replaceCloud, titleVisibility: .visible) {
                    Button("Replace cloud copy", role: .destructive) { useLocalCopy() }
                }
                .confirmationDialog("Delete the saved cloud copy? This iPhone's records remain. A newer cloud revision will block deletion so you can review it first.", isPresented: $deleteCloud, titleVisibility: .visible) {
                    Button("Delete cloud copy", role: .destructive) { removeCloudCopy() }
                }
                .onDisappear { pending?.cancel(); pending = nil }
        }
    }

    private func client(for owner: UUID) throws -> MemorySyncClient {
        guard let endpoint = AccountConfiguration.baseURL, account.accountID == owner else { throw AccountError.signInRequired }
        return MemorySyncClient(endpoint: endpoint, tokenProvider: {
            let token = try await account.validAccessToken()
            guard await account.accountID == owner else { throw AccountError.signInRequired }
            return token
        })
    }

    private func stillCurrent(owner: UUID, revision: Int) -> Bool {
        !Task.isCancelled && account.accountID == owner && memory.ownerID == owner && memory.revision == revision && consent
    }

    private func synchronize() {
        guard !busy, consent else { return }
        let owner = memory.ownerID, revision = memory.revision
        busy = true; status = nil; conflict = nil
        pending = Task { @MainActor in
            defer { busy = false; pending = nil }
            do {
                let service = try client(for: owner)
                let remote = try await service.pull(consent: consent)
                guard stillCurrent(owner: owner, revision: revision) else { status = "Your account or local data changed. Please sync again."; return }
                if remote.revision == memory.cloudRevision {
                    if memory.hasUnsyncedChanges { try await upload(service, against: remote.revision, owner: owner, revision: revision) }
                    else { status = "Your saved memories and history are up to date." }
                } else if memory.cloudRevision == nil && remote.revision == 0 && remote.archive == nil {
                    try await upload(service, against: 0, owner: owner, revision: revision)
                } else if remote.archive == nil && (!memory.memories.isEmpty || !memory.conversations.isEmpty) {
                    conflict = remote; conflictLocalRevision = revision
                    status = "The cloud copy was deleted. This iPhone's records are still here; choose whether to keep or remove them."
                } else if !memory.hasUnsyncedChanges || (memory.cloudRevision == nil && memory.memories.isEmpty && memory.conversations.isEmpty) {
                    status = memory.applyCloudSnapshot(remote, expectedLocalRevision: revision) ? "The cloud copy is now on this iPhone." : memory.errorMessage
                } else {
                    conflict = remote; conflictLocalRevision = revision
                    status = "Both copies may have changed. Nothing has been overwritten."
                }
            } catch { report(error) }
        }
    }

    private func upload(_ service: MemorySyncClient, against remoteRevision: Int, owner: UUID, revision: Int) async throws {
        let data = try memory.snapshotData()
        let result = try await service.push(archiveData: data, expectedRevision: remoteRevision, consent: consent)
        guard stillCurrent(owner: owner, revision: revision) else { status = "The upload completed, but this iPhone changed during sync. Sync again to review both copies."; return }
        status = memory.recordSuccessfulUpload(remoteRevision: result.revision, expectedLocalRevision: revision) ? "Your saved memories and history are synced." : memory.errorMessage
        conflict = nil
    }

    private func useCloudCopy() {
        guard !busy, consent, account.accountID == memory.ownerID,
              let conflict, let revision = conflictLocalRevision else { return }
        if memory.applyCloudSnapshot(conflict, expectedLocalRevision: revision) {
            self.conflict = nil; status = "The reviewed cloud copy is now on this iPhone."
        } else { status = memory.errorMessage }
    }

    private func useLocalCopy() {
        guard !busy, consent, let conflict, let revision = conflictLocalRevision else { return }
        let owner = memory.ownerID
        guard stillCurrent(owner: owner, revision: revision) else { self.conflict = nil; status = "This iPhone changed. Sync again before choosing a copy."; return }
        busy = true
        pending = Task { @MainActor in
            defer { busy = false; pending = nil }
            do { try await upload(client(for: owner), against: conflict.revision, owner: owner, revision: revision) }
            catch { report(error) }
        }
    }

    private func removeCloudCopy() {
        guard !busy, consent, let revision = memory.cloudRevision else { return }
        let owner = memory.ownerID
        busy = true
        pending = Task { @MainActor in
            defer { busy = false; pending = nil }
            do {
                _ = try await client(for: owner).delete(expectedRevision: revision, consent: consent)
                guard !Task.isCancelled, account.accountID == owner else { return }
                conflict = nil; status = "Cloud copy deleted. This iPhone's records remain; a future sync will let you review which copy to keep."
            } catch { report(error) }
        }
    }

    private func prepareLocalExport() {
        do { document = JournalExport(data: try memory.exportData()); export = true }
        catch { status = "The local copy couldn't be exported." }
    }

    private func prepareCloudExport(_ snapshot: MemoryCloudSnapshot) {
        do {
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            document = JournalExport(data: try encoder.encode(snapshot.archive)); export = true
        } catch { status = "The cloud copy couldn't be exported." }
    }

    private func report(_ error: Error) {
        guard !Task.isCancelled else { return }
        status = (error as? LocalizedError)?.errorDescription ?? "Sync couldn't finish. Your local copy is still here. Please try again."
    }
}
