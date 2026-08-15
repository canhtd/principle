import Foundation

/// Static facts about the app. `scripts/make-app.sh` reads `version` from this
/// file so the bundle and the binary never disagree.
public enum PrincipleInfo {
    public static let version = "0.1.0"
    public static let bundleIdentifier = "com.danny.principle"
}

/// Top-level sections of the app, switched from the window toolbar.
public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case chat
    case favorites

    public var id: String { rawValue }

    /// User-facing label.
    public var title: String {
        switch self {
        case .chat: "Chat"
        case .favorites: "Favorites"
        }
    }

    public var systemImage: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right"
        case .favorites: "star"
        }
    }
}
