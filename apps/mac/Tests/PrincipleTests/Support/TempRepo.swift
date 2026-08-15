import Foundation

@testable import PrincipleCore

/// A throwaway repo root under the system temp dir, removed when the test lets
/// go of it. Every suite writes here, so the real repo's `memory/` is never
/// touched; `prefix` only makes a leftover directory traceable to its suite.
final class TempRepo {
    let root: URL

    /// `create: false` hands back a path that is deliberately not there — what a
    /// mistyped repo path in Settings looks like.
    init(prefix: String, create: Bool = true) throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("principle-\(prefix)-\(UUID().uuidString)", isDirectory: true)
        if create {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
    }

    var sessions: SessionStore { SessionStore(repoURL: root) }
    var favorites: FavoritesStore { FavoritesStore(repoURL: root) }

    deinit { try? FileManager.default.removeItem(at: root) }
}
