import SwiftUI

struct MemoryConversationScreen: View {
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var memory: MemoryStore
    @EnvironmentObject private var subscription: SubscriptionStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var conversation = MemoryConversation(title: "A new conversation", messages: [])
    @State private var draft = ""
    @State private var temporary = false
    @State private var sending = false
    @State private var pending: Task<Void, Never>?
    @State private var activeRequestID: UUID?
    @State private var status: String?
    @State private var showMemory = false
    @State private var showHistory = false
    @State private var showPlus = false
    @State private var showAccount = false
    @State private var showConsent = false
    @State private var newConversation = false
    @State private var memoryToSave: MemoryMessage?
    @State private var memoryDraft = ""
    @State private var suggestions: [MemorySuggestion] = []
    @State private var suggestionSourceID: UUID?
    @State private var reviewingSuggestion = false
    @State private var selectedKind: MemoryKind = .preference
    @State private var savedInHistory = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        PageHeading(eyebrow: "A LITTLE CONTINUITY", title: "Pick up\nwhere you are.", subtitle: "A conversation with room for what matters to you.")
                        HStack(spacing: 12) {
                            Button { showMemory = true } label: { Label("Memory", systemImage: "brain.head.profile") }.accessibilityIdentifier("talk.memory")
                            Spacer()
                            Button { showHistory = true } label: { Label("History", systemImage: "clock") }.accessibilityIdentifier("talk.history")
                            Button { newConversation = true } label: { Image(systemName: "square.and.pencil").accessibilityLabel("New conversation") }
                        }.font(.system(size: 13))
                        Toggle("Temporary conversation", isOn: $temporary)
                            .disabled(!conversation.messages.isEmpty || sending)
                            .accessibilityIdentifier("talk.temporary")
                        Text(modeDescription).font(.system(size: 12)).foregroundStyle(OmniTheme.muted).lineSpacing(3)

                        if !subscription.hasPremium {
                            OmniCard(color: OmniTheme.sage) {
                                Text("A little more continuity with Plus").font(OmniTheme.title(24))
                                Text("Plus can use the memories you choose in future conversations. Existing memories and history stay yours to view, correct, delete and export.").font(.system(size: 14)).lineSpacing(4)
                                Button("Explore Plus") { showPlus = true }.font(.headline).accessibilityIdentifier("talk.plus")
                            }
                        }
                        if !chatAvailable {
                            OmniCard {
                                Label("Conversations aren't connected yet", systemImage: "bubble.left.and.bubble.right").font(.headline)
                                Text(account.hasConfiguration ? "Sign in to use your account's memories in conversations. Your local journal stays on this device." : "You can manage your memories now. Online conversation access will appear here when the service and your account are ready.").font(.system(size: 13)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                                if account.hasConfiguration { Button("Connect your account") { showAccount = true }.font(.headline) }
                            }.accessibilityIdentifier("talk.unavailable")
                        }
                        if conversation.messages.isEmpty {
                            Text("What would you like to talk through?").font(OmniTheme.title(25)).padding(.top, 6)
                            Text("You could start with a moment from today, something you need, or a conversation you're preparing for.").font(.system(size: 14)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                        }
                        ForEach(conversation.messages) { message in messageView(message).id(message.id) }
                        if !temporary && memory.settings.enabled && subscription.hasPremium {
                            ForEach(suggestions) { suggestion in
                                OmniCard(color: OmniTheme.peach.opacity(0.55)) {
                                    Eyebrow(text: "SUGGESTED, NOT SAVED")
                                    Text(suggestion.text).font(.system(size: 14)).lineSpacing(4)
                                    Text("From your words: “\(suggestion.sourceQuote)”").font(.caption).foregroundStyle(OmniTheme.muted)
                                    HStack {
                                        Button("Review memory") {
                                            guard let source = conversation.messages.first(where: { $0.id == suggestionSourceID }) else { return }
                                            selectedKind = MemoryKind(rawValue: suggestion.kind) ?? .preference
                                            memoryDraft = suggestion.text; reviewingSuggestion = true; memoryToSave = source
                                        }.font(.headline)
                                        Spacer()
                                        Button("Dismiss") { suggestions.removeAll { $0.id == suggestion.id } }.font(.caption)
                                    }
                                }
                            }
                        }
                        if sending { ProgressView("Making a little room for your thoughts…").font(.caption) }
                        if let status { Text(status).font(.system(size: 13)).foregroundStyle(OmniTheme.muted).accessibilityIdentifier("talk.status") }
                        if !conversation.messages.isEmpty, !savedInHistory, !temporary, memory.settings.saveHistory, subscription.hasPremium {
                            Button("Save this conversation") { saveCurrentConversation() }.font(.subheadline)
                        }
                        Color.clear.frame(height: 1).id("conversation.bottom")
                    }.padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: conversation.messages.count) { _, _ in withAnimation { proxy.scrollTo("conversation.bottom", anchor: .bottom) } }
                .safeAreaInset(edge: .bottom) { composer }
            }
            .background(OmniTheme.paper)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showMemory) { MemoryScreen() }
            .sheet(isPresented: $showHistory) { historySheet }
            .sheet(isPresented: $showPlus) { PlusScreen() }
            .sheet(isPresented: $showAccount) { AccountScreen() }
            .sheet(isPresented: $showConsent) { consentSheet }
            .sheet(item: $memoryToSave) { message in rememberSheet(message) }
            .confirmationDialog("Start a new conversation? Temporary and unsaved messages in this view will be cleared.", isPresented: $newConversation, titleVisibility: .visible) {
                Button("Start fresh") { clearCurrent() }
            }
            .onChange(of: memory.ownerID) { _, _ in clearCurrent() }
            .onChange(of: account.accountID) { _, _ in clearCurrent() }
            .onChange(of: memory.settings.allowOnlineConversations) { _, allowed in if !allowed { cancelReply() } }
            .onChange(of: subscription.hasPremium) { _, active in if !active { cancelReply() } }
            .onChange(of: memory.conversations.map(\.id)) { _, ids in
                if savedInHistory && !ids.contains(conversation.id) { clearCurrent() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { cancelReply(); if temporary { clearCurrent() } }
            }
            .onDisappear { cancelReply(); if temporary { clearCurrent() } }
        }
    }

    private var chatAvailable: Bool {
        account.hasConfiguration && account.accountID == memory.ownerID
    }

    private var modeDescription: String {
        if temporary { return "Only this conversation is used. Saved memories stay out, and no history or new memories are saved. Temporary messages clear when you leave this screen or background the app." }
        let remembered = memory.settings.enabled ? "Relevant saved memories can be included." : "Saved memory is off."
        return remembered + (memory.settings.saveHistory ? " Conversations are saved on this device after a reply." : " Saving history is off. Messages remain only in this view.")
    }

    private var composer: some View {
        VStack(spacing: 9) {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("What's on your mind?", text: $draft, axis: .vertical)
                    .lineLimit(1...5).focused($composerFocused)
                    .onChange(of: draft) { _, value in if value.count > 4000 { draft = String(value.prefix(4000)) } }
                    .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("talk.message")
                Button {
                    composerFocused = false
                    send()
                } label: { Image(systemName: "arrow.up").font(.headline).foregroundStyle(.white).frame(width: 46, height: 46).background(OmniTheme.ink, in: Circle()) }
                    .disabled(sending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !chatAvailable)
                    .accessibilityLabel("Send message").accessibilityIdentifier("talk.send")
            }
            if composerFocused { Button("Done") { composerFocused = false }.font(.caption).frame(maxWidth: .infinity, alignment: .trailing) }
            Text("Your choices come first. Omni can make mistakes.").font(.system(size: 10)).foregroundStyle(OmniTheme.muted)
        }.padding(.horizontal, 20).padding(.vertical, 12).background(OmniTheme.paper)
    }

    private func messageView(_ message: MemoryMessage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message.role == .user ? "YOU" : "OMNI").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(OmniTheme.muted)
            Text(message.text).font(.system(size: 15)).lineSpacing(5).textSelection(.enabled)
            if message.role == .assistant, !message.usedMemoryIDs.isEmpty {
                Button { showMemory = true } label: { Label("Context included \(message.usedMemoryIDs.count) saved \(message.usedMemoryIDs.count == 1 ? "memory" : "memories")", systemImage: "brain.head.profile") }.font(.system(size: 11))
            }
            if message.role == .user && !temporary && subscription.hasPremium && memory.settings.enabled {
                Button("Remember this…") {
                    selectedKind = .preference
                    reviewingSuggestion = false
                    memoryDraft = String(message.text.prefix(1000))
                    memoryToSave = message
                }.font(.system(size: 12))
                    .disabled(sending).accessibilityIdentifier("talk.remember")
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(message.role == .user ? OmniTheme.sage.opacity(0.6) : Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
    }

    private var consentSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeading(eyebrow: "YOUR CHOICE", title: "Before we talk.")
                    Text("When you send a message, Omni's conversation service sends it to OpenAI to generate a reply. It also sends up to eight recent messages from this conversation and, if memory is on, up to six relevant saved memories.").lineSpacing(4)
                    Text("Your journal is not included. Temporary conversations exclude saved memories. This app keeps conversation history on your device when you choose to save it. Chat itself does not create a server copy; choosing Sync account memory separately uploads saved history and memories.").lineSpacing(4)
                    Text("When memory is on, Omni may suggest details for you to review. A suggestion only becomes a saved memory after you confirm it.").font(.system(size: 13)).lineSpacing(4)
                    Text("OpenAI may retain API data under its service policies, including abuse monitoring. Turning off provider response storage is not a promise of zero retention. You can stop future sending at any time in Memory.").font(.system(size: 13)).foregroundStyle(OmniTheme.muted).lineSpacing(4)
                    Link("OpenAI API data policy", destination: URL(string: "https://developers.openai.com/api/docs/guides/your-data")!)
                    OmniButton(title: "Allow online conversations", icon: "checkmark") {
                        var settings = memory.settings
                        settings.allowOnlineConversations = true
                        if memory.setSettings(settings, premium: subscription.hasPremium) { showConsent = false }
                    }.accessibilityIdentifier("talk.allow")
                    Text("Your draft will remain here. Tap Send when you're ready.").font(.caption).foregroundStyle(OmniTheme.muted)
                }.padding(24)
            }.background(OmniTheme.paper).navigationTitle("Conversation privacy").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Not now") { showConsent = false } }
        }
    }

    private var historySheet: some View {
        NavigationStack {
            List {
                if memory.conversations.isEmpty { Text("Your saved conversations will appear here.").foregroundStyle(OmniTheme.muted) }
                ForEach(memory.conversations) { saved in
                    Button {
                        cancelReply(); conversation = saved; temporary = false; savedInHistory = true
                        status = nil; draft = ""; showHistory = false
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(saved.title).foregroundStyle(OmniTheme.ink)
                            Text(saved.updatedAt, style: .date).font(.caption).foregroundStyle(OmniTheme.muted)
                        }
                    }
                    .swipeActions { Button("Delete", role: .destructive) { _ = memory.deleteConversation(saved.id) } }
                }
                Section { Text("Deleting a conversation also removes memories saved from it. Independently added profile notes remain.").font(.caption) }
            }.navigationTitle("Conversations").toolbar { Button("Done") { showHistory = false } }
        }
    }

    private func rememberSheet(_ message: MemoryMessage) -> some View {
        NavigationStack {
            Form {
                Section("Choose the details to keep") {
                    EntryField(title: "What should Omni remember?", placeholder: "A detail you want to keep", text: $memoryDraft, maxLength: 1000)
                    if !reviewingSuggestion && message.text.count > 1000 { Text("Your message is longer than one memory. The first 1,000 characters are shown; edit this down to the details you want to keep.").font(.caption) }
                    if reviewingSuggestion { Text("This suggestion may be incomplete or wrong. Check the wording before saving.").font(.caption) }
                }
                Section("Category") { Picker("Category", selection: $selectedKind) { ForEach(MemoryKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } } }
                Section { Text("This saves the selected message as a memory for future conversations. You can edit or delete it in Memory.").font(.caption) }
            }.navigationTitle("Remember this?").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { memoryToSave = nil } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Remember") {
                            let result: SavedMemory?
                            result = memory.addMemory(kind: selectedKind, text: memoryDraft, premium: subscription.hasPremium,
                                                      sourceConversationID: savedInHistory ? conversation.id : nil,
                                                      sourceMessageID: savedInHistory ? message.id : nil)
                            if result != nil { memoryToSave = nil; suggestions = []; status = "Memory saved. You can review it any time." }
                            else { status = memory.errorMessage ?? "This memory couldn't be saved."; memoryToSave = nil }
                        }.disabled(!memory.settings.enabled || !subscription.hasPremium || sending)
                    }
                }
        }
    }

    private func send() {
        guard !sending else { return }
        guard subscription.hasPremium else { showPlus = true; return }
        guard memory.settings.allowOnlineConversations else { showConsent = true; return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let sentDraft = draft
        guard !text.isEmpty else { return }
        let memories = memory.retrieve(query: text, premium: subscription.hasPremium, temporary: temporary)
        let ownerID = memory.ownerID
        let revision = memory.revision
        let isTemporary = temporary
        let existing = conversation
        let requestID = UUID()
        activeRequestID = requestID
        sending = true; status = nil
        pending = Task { @MainActor in
            defer { if activeRequestID == requestID { sending = false; pending = nil; activeRequestID = nil } }
            do {
                try Task.checkCancellation()
                guard activeRequestID == requestID, conversation.id == existing.id,
                      ownerID == memory.ownerID, revision == memory.revision,
                      memory.settings.allowOnlineConversations, subscription.hasPremium else { return }
                let token = try await account.validAccessToken()
                guard account.accountID == ownerID, activeRequestID == requestID,
                      revision == memory.revision, memory.settings.allowOnlineConversations else { return }
                let reply = try await MemoryChatClient(sessionToken: token).reply(to: text, memories: memories, history: existing.messages,
                                                             temporary: isTemporary, ownerID: ownerID,
                                                             consent: memory.settings.allowOnlineConversations,
                                                             suggestMemories: memory.settings.enabled && !isTemporary)
                try Task.checkCancellation()
                guard activeRequestID == requestID, conversation.id == existing.id else { return }
                guard ownerID == memory.ownerID, revision == memory.revision,
                      memory.settings.allowOnlineConversations, subscription.hasPremium else {
                    status = "Your settings or saved data changed while the reply was being prepared. Send again to use the current context."
                    return
                }
                var updated = existing
                if updated.messages.isEmpty { updated.title = String(text.prefix(60)) }
                let userMessage = MemoryMessage(role: .user, text: text)
                updated.messages.append(userMessage)
                updated.messages.append(MemoryMessage(role: .assistant, text: reply.text, usedMemoryIDs: reply.usedMemoryIDs))
                updated.updatedAt = Date()
                conversation = updated
                suggestions = reply.suggestions; suggestionSourceID = userMessage.id
                if draft == sentDraft { draft = "" }
                savedInHistory = false
                if !isTemporary && memory.settings.saveHistory { saveCurrentConversation() }
            } catch is CancellationError {
                // A cancelled request must not write messages or bring erased context back.
            } catch {
                if !Task.isCancelled && activeRequestID == requestID { status = (error as? MemoryChatError)?.localizedDescription ?? "The conversation couldn't connect. Your draft is still here. Please try again." }
            }
        }
    }

    private func saveCurrentConversation() {
        guard !temporary, memory.settings.saveHistory else { return }
        savedInHistory = memory.saveConversation(conversation, premium: subscription.hasPremium)
        if !savedInHistory { status = memory.errorMessage ?? "This conversation hasn't been saved. You can try saving again." }
    }

    private func cancelReply() { activeRequestID = nil; pending?.cancel(); pending = nil; sending = false }

    private func clearCurrent() {
        cancelReply()
        conversation = MemoryConversation(title: "A new conversation", messages: [])
        savedInHistory = false; draft = ""; status = nil; temporary = false; memoryToSave = nil
        suggestions = []; suggestionSourceID = nil; memoryDraft = ""; reviewingSuggestion = false
    }
}
