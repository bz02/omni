import SwiftUI

struct DatingPhotoView: View {
    let identifier: String?
    let name: String
    @EnvironmentObject private var account: AccountStore
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { ZStack { OmniTheme.sage; VStack(spacing: 12) { Text(String(name.prefix(1)).uppercased()).font(OmniTheme.title(64)); Text("A person, beyond a picture.").font(.caption) } } }
        }.frame(height: 220).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 20))
            .accessibilityLabel(image == nil ? "No profile photo" : "Profile photo of \(name)")
            .task(id: identifier) {
                image = nil
                guard let identifier else { return }
                if let data = try? await account.authenticatedRequest(path: "/v1/dating/photos/\(identifier)") { image = UIImage(data: data) }
            }
    }
}
