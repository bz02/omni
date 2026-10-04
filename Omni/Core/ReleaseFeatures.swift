// Keep unverified new services out of the published experience.
enum ReleaseFeatures {
    #if DEBUG
    static let dating = true
    #else
    static let dating = false // Enable after moderation ownership + privacy declarations are ready.
    #endif
    static let aiImages = false
}
