import Foundation

/// Where the repo the app reads and writes lives.
///
/// U7 owns this setting; until then everything goes through this one accessor,
/// so replacing it is a one-file change. The path is never hardcoded: it comes
/// from the shared defaults suite, and only when that is empty does a fallback
/// apply.
public enum RepoLocation {
    public static let defaultsSuite = PrincipleInfo.bundleIdentifier
    public static let repoPathKey = "repoPath"

    public static func current(defaults: UserDefaults? = UserDefaults(suiteName: defaultsSuite)) -> URL {
        if let configured = defaults?.string(forKey: repoPathKey),
            case let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty
        {
            return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath, isDirectory: true)
        }
        #if DEBUG
            if let development = developmentRepoURL { return development }
        #endif
        return applicationSupportFallback
    }

    #if DEBUG
        /// A `swift run` build has no Settings yet, so it works against the repo
        /// this source file was compiled from. Found by walking up to the
        /// directory that looks like the repo root rather than by counting path
        /// components, which breaks the moment a file moves.
        static var developmentRepoURL: URL? {
            var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            while directory.path != "/" {
                if isRepoRoot(directory) { return directory }
                directory = directory.deletingLastPathComponent()
            }
            return nil
        }

        private static func isRepoRoot(_ url: URL) -> Bool {
            let fileManager = FileManager.default
            return fileManager.fileExists(atPath: url.appendingPathComponent("CLAUDE.md").path)
                && fileManager.fileExists(atPath: url.appendingPathComponent(".claude").path)
        }
    #endif

    /// Release build with nothing configured: keep sessions somewhere writable
    /// instead of guessing at a repo that may not exist.
    static var applicationSupportFallback: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return base.appendingPathComponent("Principle", isDirectory: true)
    }
}
