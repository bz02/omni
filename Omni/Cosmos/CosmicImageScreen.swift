import SwiftUI

struct CosmicImageScreen: View {
    let sign: ZodiacSign
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var theme = "horoscope"
    @State private var mood = "calm"
    @State private var occasion = "everyday"
    @State private var consent = false
    @State private var enabled = false
    @State private var checked = false
    @State private var busy = false
    @State private var picture: Image?
    @State private var error: String?
    @State private var showAccount = false
    @State private var task: Task<Void, Never>?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: "OMNI · IMAGE STUDIO", title: "Picture your\nkind of magic.", subtitle: "Create an original zodiac illustration or a styled outfit image, inspired by \(sign.rawValue).")
                    if !account.isSignedIn {
                        Button("Sign in for AI images") { showAccount = true }
                    } else if !account.hasOnlinePremium {
                        Text("AI images require an active, verified Omni Plus subscription.").font(.subheadline)
                        Button("Check my subscription") { Task { await account.refreshAccount() } }
                    } else if checked && !enabled {
                        Text("AI images aren't connected yet. You can still create and share a card in Cosmos.")
                    } else if enabled {
                        OmniCard {
                            Picker("Create", selection: $theme) { Text("Zodiac artwork").tag("horoscope"); Text("Outfit inspiration").tag("outfit") }.pickerStyle(.segmented)
                            Picker("Mood", selection: $mood) { ForEach(["calm", "confident", "romantic", "playful"], id: \.self) { Text($0.capitalized).tag($0) } }
                            if theme == "outfit" {
                                Picker("Occasion", selection: $occasion) { Text("Everyday").tag("everyday"); Text("Work").tag("work"); Text("Date night").tag("date_night") }
                            }
                            Text("Omni sends your selected sign, mood, theme and occasion to OpenAI to create this image. Your birthday, journal, memories and dating profile are not included.").font(.subheadline)
                            Toggle("Allow these choices to be sent for this image", isOn: $consent)
                            Button(busy ? "Creating your image…" : "Generate AI image", systemImage: "sparkles") { generate() }.disabled(busy || !consent).accessibilityIdentifier("cosmos.generateAIImage")
                            Text("One attempt per day with Plus, subject to the service's monthly allowance. Generation may take a couple of minutes.").font(.caption).foregroundStyle(OmniTheme.muted)
                        }.disabled(busy)
                    }
                    if busy { ProgressView("Creating… Keep this screen open.") }
                    if let picture {
                        picture.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 20))
                        Text("AI-generated · Inspired by your selected sign").font(.caption)
                        ShareLink(item: picture, preview: SharePreview("My Omni cosmic artwork", image: picture)) { Label("Share image", systemImage: "square.and.arrow.up") }
                        Text("The image is kept here while this screen is open. Share or save a copy before closing.").font(.caption)
                    }
                    if let error { Text(error).font(.subheadline).foregroundStyle(.red) }
                }.padding(24)
            }.background(OmniTheme.paper).navigationTitle("Image studio").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() }.accessibilityIdentifier("imageStudio.done") }
                .sheet(isPresented: $showAccount) { AccountScreen() }
                .task(id: account.accountID) {
                    picture = nil; consent = false; checked = false; enabled = false
                    guard account.isSignedIn else { return }
                    do {
                        struct Status: Decodable { let enabled: Bool }
                        let data = try await account.authenticatedRequest(path: "/v1/cosmos/images/status")
                        enabled = try JSONDecoder().decode(Status.self, from: data).enabled; checked = true
                    } catch { checked = true; self.error = error.localizedDescription }
                }
                .onChange(of: theme) { _, _ in consent = false }
                .onChange(of: mood) { _, _ in consent = false }
                .onChange(of: occasion) { _, _ in consent = false }
                .onDisappear { task?.cancel(); picture = nil; consent = false }
        }.interactiveDismissDisabled(busy)
    }
    private func generate() {
        guard consent && !busy else { return }
        busy = true; error = nil; picture = nil
        let owner = account.accountID
        task = Task { @MainActor in
            defer { busy = false; consent = false }
            do {
                struct Body: Encodable { let request_id: UUID; let sign: String; let theme: String; let mood: String; let occasion: String; let consent: Bool }
                struct Result: Decodable { let image_base64: String; let mime_type: String }
                let body = try JSONEncoder().encode(Body(request_id: UUID(), sign: sign.rawValue, theme: theme, mood: mood, occasion: occasion, consent: true))
                let data = try await account.authenticatedRequest(path: "/v1/cosmos/images", method: "POST", body: body)
                try Task.checkCancellation()
                guard owner == account.accountID else { throw CancellationError() }
                let result = try JSONDecoder().decode(Result.self, from: data)
                guard result.mime_type == "image/jpeg", let bytes = Data(base64Encoded: result.image_base64), bytes.count <= 2_000_000,
                      let image = UIImage(data: bytes), image.size.width <= 2048, image.size.height <= 2048 else { throw AccountError.invalidResponse }
                picture = Image(uiImage: image)
            } catch is CancellationError { }
            catch AccountError.http(429) { error = "Today's image allowance or the service's monthly allowance has been reached. On-device share cards are still available." }
            catch AccountError.http(409) { error = "This request was already attempted. Omni has not started a duplicate generation." }
            catch { self.error = "The image couldn't be completed. Please try another day. No automatic generation retry was made." }
        }
    }
}
