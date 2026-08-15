import Foundation

/// Everything the app *says* about the engine's state (KTD4, AE5).
///
/// The wording lives here rather than in the two views and the view model that
/// show it, so a blocked engine cannot be explained three slightly different
/// ways. Icons and tints stay with the views — those are looks, not words.
extension EngineAvailability {
    public static let notInstalledGuidance =
        "Không tìm thấy Claude Code trên máy. Cài đặt rồi mở lại app, hoặc trỏ đúng đường dẫn trong Cài đặt."

    /// Also used by Settings for the repo field, so the two places that can
    /// report a wrong repo say the same thing.
    public static func skillMissingGuidance(repoPath: String) -> String {
        """
        Thư mục đang dùng không phải repo Principle: \(repoPath)
        Ở đó không có \(PrincipleRepo.skillRelativePath), nên Claude Code không chạy được cuộc tư vấn.
        Mở Cài đặt → Thư mục repo và chọn thư mục gốc của repo Principle — thư mục có \
        \(PrincipleRepo.markerRelativePath) và thư mục .claude/skills/ask-ray/.
        """
    }

    /// What to tell the user when the engine cannot run; `nil` when it can.
    /// Always says what to do next, because the fix happens in a terminal.
    public var guidance: String? {
        switch self {
        case .ready: nil
        case .notInstalled: Self.notInstalledGuidance
        case .loggedOut(let guidance): guidance
        case .skillMissing(let repoPath): Self.skillMissingGuidance(repoPath: repoPath)
        }
    }

    /// The one-line status in Settings, where the version is worth reading.
    public var settingsTitle: String {
        switch self {
        case .ready(let version): "Sẵn sàng — Claude Code \(version)"
        case .notInstalled: "Không tìm thấy Claude Code"
        case .loggedOut: "Chưa đăng nhập"
        case .skillMissing: Self.skillMissingTitle
        }
    }

    /// The headline on the screen that replaces the chat when a turn cannot run
    /// (AE5). `.ready` never reaches it — that screen is only shown when blocked.
    public var blockedTitle: String {
        switch self {
        case .notInstalled: "Chưa tìm thấy Claude Code"
        case .loggedOut: "Claude Code chưa sẵn sàng"
        case .skillMissing: Self.skillMissingTitle
        case .ready: EngineAvailability.checkingTitle
        }
    }

    static let skillMissingTitle = "Chưa trỏ tới repo Principle"

    /// Shown until the first check comes back.
    public static let checkingTitle = "Đang kiểm tra engine"
}
