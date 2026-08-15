import Foundation

/// Everything the app *says* about the engine's state (KTD4, AE5).
///
/// The wording lives here rather than in the two views and the view model that
/// show it, so a blocked engine cannot be explained three slightly different
/// ways. Icons and tints stay with the views — those are looks, not words.
extension EngineAvailability {
    public static let notInstalledGuidance =
        "Không tìm thấy Claude Code trên máy. Cài đặt rồi mở lại app, hoặc trỏ đúng đường dẫn trong Cài đặt."

    /// What to tell the user when the engine cannot run; `nil` when it can.
    /// Always says what to do next, because the fix happens in a terminal.
    public var guidance: String? {
        switch self {
        case .ready: nil
        case .notInstalled: Self.notInstalledGuidance
        case .loggedOut(let guidance): guidance
        }
    }

    /// The one-line status in Settings, where the version is worth reading.
    public var settingsTitle: String {
        switch self {
        case .ready(let version): "Sẵn sàng — Claude Code \(version)"
        case .notInstalled: "Không tìm thấy Claude Code"
        case .loggedOut: "Chưa đăng nhập"
        }
    }

    /// The headline on the screen that replaces the chat when a turn cannot run
    /// (AE5). `.ready` never reaches it — that screen is only shown when blocked.
    public var blockedTitle: String {
        switch self {
        case .notInstalled: "Chưa tìm thấy Claude Code"
        case .loggedOut: "Claude Code chưa sẵn sàng"
        case .ready: EngineAvailability.checkingTitle
        }
    }

    /// Shown until the first check comes back.
    public static let checkingTitle = "Đang kiểm tra engine"
}
