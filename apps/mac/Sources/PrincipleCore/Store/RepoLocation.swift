import Foundation

/// Where the repo the app reads and writes lives.
///
/// The path itself is `AppSettings`' business — this stays as the one accessor
/// every store goes through, and owns only what Settings cannot answer: what to
/// do when nothing is configured.
public enum RepoLocation {
    public static let defaultsSuite = AppSettings.defaultsSuite
    public static let repoPathKey = AppSettings.Key.repoPath

    /// Where the repo usually sits on this machine. Tried in order when nothing
    /// is configured, so a first launch of the shipped app lands on the real repo
    /// instead of a writable folder with no skill in it.
    public static let wellKnownCandidates = [
        "~/Documents/Projects/Principle",
        "~/Documents/Projects/principle",
        "~/Projects/Principle",
    ]

    public static func current(
        defaults: UserDefaults? = AppSettings.sharedDefaults(),
        candidates: [String] = wellKnownCandidates,
        fileManager: FileManager = .default
    ) -> URL {
        if let configured = AppSettings.repoPath(in: defaults) {
            return AppSettings.expandedURL(configured)
        }
        #if DEBUG
            if let development = developmentRepoURL { return development }
        #endif
        if let found = firstPrincipleRepo(in: candidates, fileManager: fileManager) { return found }
        return applicationSupportFallback
    }

    /// First candidate that really is the repo. A candidate that is missing, or
    /// is some other project, is skipped rather than guessed at.
    static func firstPrincipleRepo(in candidates: [String], fileManager: FileManager = .default) -> URL? {
        candidates.lazy
            .map { AppSettings.expandedURL($0) }
            .first { PrincipleRepo.isPrincipleRepo(at: $0, fileManager: fileManager) }
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

    /// Nothing configured and no candidate on disk: keep sessions somewhere
    /// writable instead of guessing at a repo that may not exist. A turn is then
    /// blocked by the skill check, which says how to point Settings at the repo.
    static var applicationSupportFallback: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return base.appendingPathComponent("Principle", isDirectory: true)
    }
}
