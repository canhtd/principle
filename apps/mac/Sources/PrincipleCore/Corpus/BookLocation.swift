import Foundation

/// Where the book itself is, so a principle on screen can be opened in Apple
/// Books and read in context.
///
/// Found rather than hardcoded, the same way ``RepoLocation`` finds the repo: a
/// path written into the source is a path that is wrong on the next machine.
/// Books' own library folder is tried first, because opening the copy Books
/// already has is what avoids importing a second one.
public enum BookLocation {
    /// Folders that hold an epub worth opening, in the order they are tried.
    public static let searchDirectories = [
        "~/Library/Mobile Documents/iCloud~com~apple~iBooks/Documents",
        "~/Documents/Books",
        "~/Books",
    ]

    /// A file is the book if its name says so — the translation ships under
    /// several names ("VIE - Principles - Dalio, Ray-update V1.epub"), and all
    /// of them contain this word.
    static let titleNeedle = "principles"

    /// The local epub, or `nil` when there is none to open — a normal state, and
    /// one the popover has to say rather than pretend about.
    public static func principlesBookURL(
        override: String? = nil,
        directories: [String] = searchDirectories,
        fileManager: FileManager = .default
    ) -> URL? {
        if let override, !override.isEmpty {
            let url = URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
            if fileManager.fileExists(atPath: url.path) { return url }
        }
        for directory in directories {
            let root = URL(fileURLWithPath: (directory as NSString).expandingTildeInPath, isDirectory: true)
            guard let names = try? fileManager.contentsOfDirectory(atPath: root.path) else { continue }
            let match = names
                .filter { $0.lowercased().hasSuffix(".epub") && $0.lowercased().contains(titleNeedle) }
                .sorted()
                .first
            if let match { return root.appendingPathComponent(match) }
        }
        return nil
    }

    /// What Books can and cannot be asked for.
    ///
    /// Books' `ibooks://assetid/<id>` scheme addresses store purchases; handed
    /// the id of a book added by hand it does nothing at all (verified against
    /// the local library, 2026-08-18). There is no public way to open a local
    /// epub at a chapter, a page or a CFI locator, so "Open in Books" opens the
    /// book and stops there — one step short of what the prototype's tooltip
    /// promised.
    public static let deepLinkLimitation =
        "Books opens the book, not the page: Apple has no public link into a chapter of a local epub."
}
