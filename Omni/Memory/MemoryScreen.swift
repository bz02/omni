import SwiftUI
import UniformTypeIdentifiers

struct MemoryScreen: View {
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var memory: MemoryStore
    @EnvironmentObject private var subscription: SubscriptionStore
    @EnvironmentObject private var clarity: ClarityStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selectedKind: MemoryKind?
    @State private var editor: MemoryEditorRoute?
    @State private var pendingDraft: String?
    @State private var paywall = false
    @State private var enableConfirmation = false
    @State private var clearConfirmation = false
    @State private var recoverConfirmation = false
    @State private var deletion: SavedMemory?
    @State private var exporting = false
    @State private var document = JournalExport(data: Data())
    @State private var exportMessage: String?
    @FocusState private var searchFocused: Bool

    private var isActive: Bool { memory.settings.enabled && subscription.hasPremium }
    private var filteredMemories: [SavedMemory] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return memory.memories.filter { item in
            (selectedKind == nil || item.kind == selectedKind) &&
            (query.isEmpty || item.text.localizedCaseInsensitiveContains(query) || item.kind.title.localizedCaseInsensitiveContains(query))
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: "A LITTLE CONTINUITY", title: "What Omni\nremembers.", subtitle: "The details you choose to keep, in your own words. You can change your mind.")
                    if memory.recoveryRequired {
                        recoveryCard
                    } else {
                        settingsCard
                        historySettingsCard
                        if let error = memory.errorMessage {
                            Text(error).font(.subheadline).foregroundStyle(OmniTheme.muted).accessibilityIdentifier("memory.error")
                        }
                        library
                        controls
                    }
                    if let exportMessage {
                        Text(exportMessage).font(.subheadline).foregroundStyle(OmniTheme.muted).accessibilityIdentifier("memory.exportError")
                    }
                }.padding(24).padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(OmniTheme.paper)
            .foregroundStyle(OmniTheme.ink)
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("memory.done") }
                if searchFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { searchFocused = false }.accessibilityIdentifier("keyboard.done")
                    }
                }
            }
            .sheet(item: $editor) { route in MemoryEditorScreen(existing: route.memory, initialText: route.initialText) }
            .sheet(isPresented: $paywall) { PlusScreen() }
            .confirmationDialog("Let Omni use the memories you choose?", isPresented: $enableConfirmation, titleVisibility: .visible) {
                Button("Turn on memory") {
                    if setEnabled(true), let draft = pendingDraft {
                        editor = MemoryEditorRoute(memory: nil, initialText: draft)
                    }
                    pendingDraft = nil
                }
                Button("Cancel", role: .cancel) { pendingDraft = nil }
            } message: {
                Text("Saved details can help personalize future conversations. You choose what to save and can edit or delete it anytime. Account memory can also be uploaded when you separately choose Sync account memory.")
            }
            .confirmationDialog("Delete all saved memories?", isPresented: $clearConfirmation, titleVisibility: .visible) {
                Button("Delete all memories", role: .destructive) { _ = memory.clearMemories() }
            } message: {
                Text("This cannot be undone. Your saved conversations stay in your conversation history. Deleting memories does not delete exported copies.")
            }
            .confirmationDialog("Delete this memory?", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } }), titleVisibility: .visible) {
                Button("Delete memory", role: .destructive) {
                    if let deletion { _ = memory.deleteMemory(deletion.id) }
                    deletion = nil
                }
            } message: {
                Text("Omni will no longer use this saved detail. The original conversation, if any, stays in your history.")
            }
            .confirmationDialog("Erase the unreadable memory archive?", isPresented: $recoverConfirmation, titleVisibility: .visible) {
                Button("Erase memory archive", role: .destructive) { _ = memory.reset() }
            } message: {
                Text("Export a backup first. This erases saved memories, conversations and memory settings on this device. It cannot be undone.")
            }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Omni-memory-and-conversations") { result in
                if case .failure = result { exportMessage = "Your export couldn't be saved. Please try again." }
            }
        }
    }

    private var settingsCard: some View {
        OmniCard(color: OmniTheme.sage) {
            Toggle(isOn: Binding(get: { isActive }, set: { enabled in
                if enabled {
                    if subscription.hasPremium { pendingDraft = nil; enableConfirmation = true }
                    else { paywall = true }
                } else { setEnabled(false) }
            })) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Personal memory").font(.system(size: 18, weight: .medium))
                    Text(isActive ? "On · saved details can be used" : "Off · saved details aren't used")
                        .font(.system(size: 12)).foregroundStyle(OmniTheme.muted)
                }
            }.tint(OmniTheme.ink).accessibilityIdentifier("memory.enabled")
            Text("Only details you choose to save become memories. Omni doesn't automatically turn your conversations into a profile.")
                .font(.system(size: 14)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
            if !subscription.hasPremium {
                Text("A Plus subscription lets you add and use memories. Your existing memories remain available to view, edit, delete and export.")
                    .font(.system(size: 13)).foregroundStyle(OmniTheme.muted).lineSpacing(3)
            }
            if memory.settings.enabled && !subscription.hasPremium {
                Button("Keep memory off") { setEnabled(false) }
                    .font(.system(size: 14, weight: .medium)).accessibilityIdentifier("memory.keepOff")
            }
            Label(account.accountID == memory.ownerID ? "Account memory · choose Sync to update the cloud" : "Local memory · stays on this device", systemImage: "iphone")
                .font(.system(size: 11)).foregroundStyle(OmniTheme.muted)
        }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your saved details").font(OmniTheme.title(27))
                Spacer()
                Text("\(memory.memories.count)").font(.system(size: 13, design: .monospaced)).foregroundStyle(OmniTheme.muted)
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(OmniTheme.muted)
                TextField("Search your memories", text: $search)
                    .focused($searchFocused).submitLabel(.search)
                    .onSubmit { searchFocused = false }
                    .accessibilityIdentifier("memory.search")
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear search")
                }
            }.padding(15).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 15))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterButton(nil)
                    ForEach(MemoryKind.allCases) { kind in filterButton(kind) }
                }
            }
            if memory.memories.isEmpty {
                OmniCard {
                    Image(systemName: "leaf").font(.system(size: 28, weight: .light)).foregroundStyle(OmniTheme.gold)
                    Text("Start with what matters.").font(OmniTheme.title(25))
                    Text("Keep a preference, a goal, or something about an important relationship. Add a detail here, or choose a message to remember from a conversation.")
                        .font(.system(size: 14)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                }.accessibilityIdentifier("memory.empty")
            } else if filteredMemories.isEmpty {
                Text("No memories match yet. Try another search or category.")
                    .font(.subheadline).foregroundStyle(OmniTheme.muted).padding(.vertical, 12)
                    .accessibilityIdentifier("memory.noMatches")
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(filteredMemories) { item in memoryCard(item) }
                }
            }
            OmniButton(title: "Add a memory", icon: "plus") { addMemory() }
                .accessibilityIdentifier("memory.add")
            if clarity.profile != nil {
                Button { addMemory(draft: profileDraft) } label: {
                    Label("Remember my profile", systemImage: "person.crop.rectangle")
                        .font(.system(size: 14, weight: .medium))
                }.accessibilityIdentifier("memory.rememberProfile")
                Text("Review your name and current focus before saving them as a memory.")
                    .font(.system(size: 12)).foregroundStyle(OmniTheme.muted)
            }
        }
    }

    private var historySettingsCard: some View {
        OmniCard {
            Toggle("Save conversation history", isOn: Binding(get: { memory.settings.saveHistory }, set: { value in
                var settings = memory.settings
                settings.saveHistory = value
                _ = memory.setSettings(settings, premium: subscription.hasPremium)
            }))
                .tint(OmniTheme.ink).font(.system(size: 15, weight: .medium))
                .accessibilityIdentifier("memory.saveHistory")
            Text("Save future conversations on this device so you can return to them. Turning this off keeps existing history. Temporary conversations aren't saved.")
                .font(.system(size: 13)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
            if memory.settings.allowOnlineConversations {
                Divider()
                Toggle("Allow online conversations", isOn: Binding(get: { memory.settings.allowOnlineConversations }, set: { value in
                    guard !value else { return }
                    var settings = memory.settings
                    settings.allowOnlineConversations = false
                    _ = memory.setSettings(settings, premium: subscription.hasPremium)
                })).tint(OmniTheme.ink).font(.system(size: 15, weight: .medium))
                    .accessibilityIdentifier("memory.allowOnline")
                Text("When you send a message, Omni's conversation service sends it, up to 8 recent messages in that conversation, and up to 6 relevant memories to OpenAI. Turning this off stops new requests.")
                    .font(.system(size: 13)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                Text("Omni's service does not save these conversations in this app mode. OpenAI has its own data retention policy. Turning off permission doesn't recall information already sent.")
                    .font(.system(size: 12)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
            } else if MemoryChatClient.endpoint != nil {
                Divider()
                Label("Online conversations are off", systemImage: "network.slash")
                    .font(.system(size: 14, weight: .medium))
                Text("You can review the details and choose whether to allow them before sending a conversation message.")
                    .font(.system(size: 13)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 18) {
            Rectangle().fill(OmniTheme.line).frame(height: 0.7)
            Button { prepareExport() } label: {
                Label("Export memories & conversations", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
            }.accessibilityIdentifier("memory.export")
            Text("Your export is a readable file containing your saved memories and conversation history. Choose where to keep it carefully. Deleting the app can remove local records.")
                .font(.system(size: 12)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
            if !memory.memories.isEmpty {
                Button("Delete all memories", role: .destructive) { clearConfirmation = true }
                    .font(.system(size: 14)).accessibilityIdentifier("memory.clear")
            }
        }
    }

    private var recoveryCard: some View {
        OmniCard(color: OmniTheme.sage) {
            Text("Let's protect your memories.").font(OmniTheme.title(26))
            Text(memory.errorMessage ?? "This memory archive couldn't be opened. Your original file has been kept.")
                .font(.subheadline).foregroundStyle(OmniTheme.muted)
            OmniButton(title: "Export a backup", icon: "square.and.arrow.up") { prepareExport() }
            Button("Erase memory archive and start again", role: .destructive) { recoverConfirmation = true }
                .font(.system(size: 13))
        }
    }

    private func filterButton(_ kind: MemoryKind?) -> some View {
        Button { selectedKind = kind } label: {
            Text(kind?.title ?? "All").font(.system(size: 12, weight: .medium)).fixedSize()
                .padding(.horizontal, 15).padding(.vertical, 10)
                .foregroundStyle(selectedKind == kind ? Color.white : OmniTheme.ink)
                .background(selectedKind == kind ? OmniTheme.ink : OmniTheme.sage, in: Capsule())
        }.buttonStyle(.plain)
            .accessibilityIdentifier("memory.filter." + (kind?.rawValue ?? "all"))
            .accessibilityAddTraits(selectedKind == kind ? .isSelected : [])
    }

    private func memoryCard(_ item: SavedMemory) -> some View {
        OmniCard {
            HStack {
                Eyebrow(text: item.kind.title)
                Spacer()
                Menu {
                    Button("Edit memory", systemImage: "pencil") { editor = MemoryEditorRoute(memory: item) }
                    Button("Delete memory", systemImage: "trash", role: .destructive) { deletion = item }
                } label: {
                    Image(systemName: "ellipsis").padding(10).contentShape(Rectangle())
                }.accessibilityLabel("Options for \(item.kind.title) memory")
                    .accessibilityIdentifier("memory.options." + item.id.uuidString)
            }
            Text(item.text).font(.system(size: 16)).lineSpacing(4).textSelection(.enabled)
            VStack(alignment: .leading, spacing: 5) {
                Label(item.sourceConversationID == nil ? "Added by you" : "Saved from your conversation", systemImage: item.sourceConversationID == nil ? "pencil" : "bubble.left")
                Text("Updated \(item.updatedAt.formatted(date: .abbreviated, time: .omitted))")
            }.font(.system(size: 11)).foregroundStyle(OmniTheme.muted)
        }.accessibilityElement(children: .contain)
            .accessibilityIdentifier("memory.item." + item.id.uuidString)
    }

    @discardableResult
    private func setEnabled(_ enabled: Bool) -> Bool {
        var settings = memory.settings
        settings.enabled = enabled
        return memory.setSettings(settings, premium: subscription.hasPremium)
    }

    private var profileDraft: String {
        guard let profile = clarity.profile else { return "" }
        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (name.isEmpty ? "" : "My name is \(name). ") + "My current focus is \(profile.focus.rawValue.lowercased())."
    }

    private func addMemory(draft: String = "") {
        searchFocused = false
        guard subscription.hasPremium else { paywall = true; return }
        guard memory.settings.enabled else { pendingDraft = draft; enableConfirmation = true; return }
        editor = MemoryEditorRoute(memory: nil, initialText: draft)
    }

    private func prepareExport() {
        exportMessage = nil
        do { document = JournalExport(data: try memory.exportData()); exporting = true }
        catch { exportMessage = "Your archive couldn't be prepared for export. Please try again." }
    }
}

private struct MemoryEditorRoute: Identifiable {
    let id = UUID()
    let memory: SavedMemory?
    var initialText = ""
}

private struct MemoryEditorScreen: View {
    @EnvironmentObject private var memory: MemoryStore
    @EnvironmentObject private var subscription: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    let existing: SavedMemory?
    let initialText: String
    @State private var kind: MemoryKind = .profile
    @State private var text = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: "IN YOUR OWN WORDS", title: existing == nil ? "A detail worth\nremembering." : "Make it feel\nlike you.", subtitle: "Keep it specific and current. You decide what belongs here.")
                    Picker("Category", selection: $kind) {
                        ForEach(MemoryKind.allCases) { item in Text(item.title).tag(item) }
                    }.pickerStyle(.menu).tint(OmniTheme.ink)
                        .accessibilityIdentifier("memory.editor.kind")
                    EntryField(title: "What would you like Omni to remember?", placeholder: "Write a detail in your own words", text: $text, maxLength: 1000)
                    Text("Avoid passwords, payment details, and private information someone else hasn't agreed to share.")
                        .font(.system(size: 12)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                    if let error = memory.errorMessage {
                        Text(error).font(.subheadline).foregroundStyle(OmniTheme.muted)
                    }
                    OmniButton(title: "Save memory", icon: "checkmark") { save() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("memory.editor.save")
                }.padding(24)
            }.scrollDismissesKeyboard(.interactively)
                .background(OmniTheme.paper).foregroundStyle(OmniTheme.ink)
                .navigationTitle(existing == nil ? "Add a memory" : "Edit memory")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }.accessibilityIdentifier("memory.editor.cancel")
                    }
                }
        }.onAppear {
            if let existing { kind = existing.kind; text = existing.text }
            else { text = initialText }
        }
    }

    private func save() {
        if let existing {
            if memory.updateMemory(id: existing.id, kind: kind, text: text) { dismiss() }
        } else if memory.addMemory(kind: kind, text: text, premium: subscription.hasPremium) != nil {
            dismiss()
        }
    }
}
