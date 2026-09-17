import SwiftUI

enum OmniTheme {
    static let paper = Color(hex: "F7F5EF")
    static let ink = Color(hex: "253E38")
    static let muted = Color(hex: "65736B")
    static let line = Color(hex: "DCDDD3")
    static let sage = Color(hex: "E5EADF")
    static let peach = Color(hex: "F2E2D5")
    static let gold = Color(hex: "A58E5B")
    static let cream = Color(hex: "F2F0E5")
    static func title(_ size: CGFloat = 40) -> Font { .system(size: size, weight: .regular, design: .serif) }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(cleaned, radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, opacity: 1)
    }
}

struct OmniButton: View {
    let title: String
    var icon: String = "arrow.right"
    var light = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack { Text(title).font(.system(size: 16, weight: .semibold)); Spacer(); Image(systemName: icon) }
                .padding(.horizontal, 22).frame(minHeight: 56)
                .foregroundStyle(light ? OmniTheme.ink : .white)
                .background(light ? OmniTheme.sage : OmniTheme.ink, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(OmniTheme.muted)
    }
}

struct OmniCard<Content: View>: View {
    var color: Color = .white.opacity(0.65)
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(OmniTheme.line.opacity(0.7), lineWidth: 0.7))
    }
}

struct CelestialArt: View {
    var compact = false
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().fill(OmniTheme.sage.opacity(0.55)).frame(width: side * 0.9)
                Circle().stroke(OmniTheme.gold.opacity(0.45), lineWidth: 0.8).frame(width: side * 0.83)
                Ellipse().stroke(OmniTheme.gold.opacity(0.5), lineWidth: 0.8).frame(width: side * 0.98, height: side * 0.36).rotationEffect(.degrees(-28))
                Ellipse().stroke(OmniTheme.gold.opacity(0.4), lineWidth: 0.8).frame(width: side * 0.98, height: side * 0.36).rotationEffect(.degrees(35))
                Circle().fill(LinearGradient(colors: [Color(hex: "D1AA75"), Color(hex: "EFDBB6"), Color(hex: "F9EBD0")], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: side * 0.43)
                    .shadow(color: OmniTheme.gold.opacity(0.15), radius: 18, y: 12)
                Image(systemName: "sparkle").font(.system(size: side * 0.075, weight: .light)).foregroundStyle(OmniTheme.ink).offset(x: side * 0.32, y: -side * 0.3)
                Circle().fill(OmniTheme.ink).frame(width: side * 0.035).offset(x: -side * 0.34, y: side * 0.16)
                Circle().stroke(OmniTheme.gold, lineWidth: 1).frame(width: side * 0.07).offset(x: side * 0.24, y: side * 0.31)
            }.frame(width: geo.size.width, height: geo.size.height)
        }.accessibilityHidden(true)
    }
}

struct FeelingPicker: View {
    @Binding var selection: Feeling
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { ForEach(Feeling.allCases) { feeling in feelingButton(feeling) } }
            VStack(spacing: 8) { ForEach(Feeling.allCases) { feeling in feelingButton(feeling) } }
        }
    }
    private func feelingButton(_ feeling: Feeling) -> some View {
        Button { selection = feeling } label: {
            VStack(spacing: 9) {
                Image(systemName: feeling.symbol).font(.system(size: 22, weight: .light))
                Text(feeling.label).font(.system(size: 10, weight: .medium)).fixedSize()
            }.frame(maxWidth: .infinity).padding(.vertical, 15).padding(.horizontal, 5)
                .foregroundStyle(selection == feeling ? Color.white : OmniTheme.ink)
                .background(selection == feeling ? OmniTheme.ink : OmniTheme.sage.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).accessibilityLabel(feeling.label).accessibilityAddTraits(selection == feeling ? .isSelected : [])
    }
}

struct EntryField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var maxLength = 1500
    @FocusState private var fieldIsFocused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 17, weight: .medium))
            TextField(placeholder, text: $text, axis: .vertical).lineLimit(3...7)
                .accessibilityIdentifier("field." + title)
                .focused($fieldIsFocused)
                .submitLabel(.done)
                .onSubmit { fieldIsFocused = false }
                .padding(16).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(OmniTheme.line, lineWidth: 1))
                .onChange(of: text) { _, value in if value.count > maxLength { text = String(value.prefix(maxLength)) } }
            Text("\(text.count)/\(maxLength)").font(.caption2).foregroundStyle(OmniTheme.muted).frame(maxWidth: .infinity, alignment: .trailing)
        }.toolbar {
            if fieldIsFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { fieldIsFocused = false }.accessibilityIdentifier("keyboard.done")
                }
            }
        }
    }
}

struct PageHeading: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: eyebrow)
            Text(title).font(OmniTheme.title()).fixedSize(horizontal: false, vertical: true)
            if let subtitle { Text(subtitle).font(.system(size: 15)).foregroundStyle(OmniTheme.muted).lineSpacing(4) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
