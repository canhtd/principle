import Foundation

/// Everything the app *says* about the engine's state (KTD4, AE5).
///
/// The wording lives here rather than in the two views and the view model that
/// show it, so a blocked engine cannot be explained three slightly different
/// ways. Icons and tints stay with the views — those are looks, not words.
extension EngineAvailability {
    public static let notInstalledGuidance =
        """
        Claude Code was not found on this Mac. Install it and reopen the app, or point Settings \
        at the right path.
        """

    /// Also used by Settings for the repo field, so the two places that can
    /// report a wrong repo say the same thing.
    public static func skillMissingGuidance(repoPath: String) -> String {
        """
        This folder is not the Principle repo: \(repoPath)
        It has no \(PrincipleRepo.skillRelativePath), so Claude Code cannot run the consultation.
        Open Settings → Repo Folder and choose the root folder of the Principle repo — the one \
        that has \(PrincipleRepo.markerRelativePath) and a .claude/skills/ask-ray/ folder.
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
        case .ready(let version): "Ready — Claude Code \(version)"
        case .notInstalled: "Claude Code not found"
        case .loggedOut: "Not signed in"
        case .skillMissing: Self.skillMissingTitle
        }
    }

    /// The headline on the screen that replaces the chat when a turn cannot run
    /// (AE5). `.ready` never reaches it — that screen is only shown when blocked.
    public var blockedTitle: String {
        switch self {
        case .notInstalled: "Claude Code not found"
        case .loggedOut: "Claude Code is not ready"
        case .skillMissing: Self.skillMissingTitle
        case .ready: EngineAvailability.checkingTitle
        }
    }

    static let skillMissingTitle = "Not pointed at the Principle repo"

    /// Shown until the first check comes back.
    public static let checkingTitle = "Checking the engine"
}
