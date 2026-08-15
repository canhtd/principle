import Foundation

/// What makes a directory *the* Principle repo rather than any writable folder.
///
/// A turn is spawned with the repo as its working directory, and the whole
/// consultation is `/ask-ray` — a skill that only exists inside this repo. Point
/// the app anywhere else and the engine answers `Unknown command: /ask-ray`, so
/// the check has to happen before the spawn, not after.
///
/// Pure on purpose: path in, answer out. No defaults, no process, no main actor.
public enum PrincipleRepo {
    /// The one file whose absence produces that failure.
    public static let skillRelativePath = ".claude/skills/ask-ray/SKILL.md"
    /// Present in every checkout; keeps a bare `.claude` directory elsewhere on
    /// disk from passing as the repo.
    public static let markerRelativePath = "CLAUDE.md"

    /// The gate a turn has to pass: the skill the consultation runs is there.
    public static func hasAskRaySkill(at root: URL, fileManager: FileManager = .default) -> Bool {
        exists(skillRelativePath, in: root, fileManager: fileManager)
    }

    /// The stricter test used when *guessing* a repo the user never configured:
    /// a wrong guess is worse than no guess, so both markers must be there.
    public static func isPrincipleRepo(at root: URL, fileManager: FileManager = .default) -> Bool {
        exists(markerRelativePath, in: root, fileManager: fileManager)
            && hasAskRaySkill(at: root, fileManager: fileManager)
    }

    private static func exists(_ relativePath: String, in root: URL, fileManager: FileManager) -> Bool {
        fileManager.fileExists(atPath: root.appendingPathComponent(relativePath).path)
    }
}
