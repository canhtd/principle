import Foundation

@testable import PrincipleCore

/// A throwaway repo root under the system temp dir, removed when the test lets
/// go of it. Every suite writes here, so the real repo's `memory/` is never
/// touched; `prefix` only makes a leftover directory traceable to its suite.
final class TempRepo {
    let root: URL

    /// `create: false` hands back a path that is deliberately not there — what a
    /// mistyped repo path in Settings looks like. `skill: false` creates the
    /// folder without the `ask-ray` skill — what pointing Settings at some other
    /// directory looks like, which blocks every turn.
    init(prefix: String, create: Bool = true, skill: Bool = true) throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("principle-\(prefix)-\(UUID().uuidString)", isDirectory: true)
        if create {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if skill { try Self.makePrincipleRepo(at: root) }
        }
    }

    /// The two markers `PrincipleRepo` looks for, and nothing else: the tests
    /// care that a turn is allowed to run here, not what the files say.
    static func makePrincipleRepo(at root: URL) throws {
        let skill = root.appendingPathComponent(PrincipleRepo.skillRelativePath)
        try FileManager.default.createDirectory(
            at: skill.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "# ask-ray\n".write(to: skill, atomically: true, encoding: .utf8)
        try "# Principle\n".write(
            to: root.appendingPathComponent(PrincipleRepo.markerRelativePath),
            atomically: true,
            encoding: .utf8)
    }

    var sessions: SessionStore { SessionStore(repoURL: root) }
    var favorites: FavoritesStore { FavoritesStore(repoURL: root) }

    deinit { try? FileManager.default.removeItem(at: root) }
}
