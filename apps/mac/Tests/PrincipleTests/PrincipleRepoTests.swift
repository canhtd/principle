import Foundation
import Testing

@testable import PrincipleCore

/// The release build shipped without this check answered the very first question
/// with `Unknown command: /ask-ray`: the engine ran fine, in a folder that had no
/// skill in it. Everything here is a pure path question, so it is answered
/// without a `claude` binary anywhere near it.
@Suite("Principle repo")
struct PrincipleRepoTests {
    // MARK: - The predicate

    @Test("A folder with the ask-ray skill can run a turn; a bare folder cannot")
    func skillDecidesWhetherATurnCanRun() throws {
        let repo = try TempRepo(prefix: "repo-check")
        let plain = try TempRepo(prefix: "repo-check-plain", skill: false)

        #expect(PrincipleRepo.hasAskRaySkill(at: repo.root))
        #expect(PrincipleRepo.isPrincipleRepo(at: repo.root))
        #expect(!PrincipleRepo.hasAskRaySkill(at: plain.root))
        #expect(!PrincipleRepo.isPrincipleRepo(at: plain.root))
    }

    @Test("A folder that is not there at all is not the repo")
    func missingFolderIsNotTheRepo() throws {
        let gone = try TempRepo(prefix: "repo-check-gone", create: false)

        #expect(!PrincipleRepo.hasAskRaySkill(at: gone.root))
        #expect(!PrincipleRepo.isPrincipleRepo(at: gone.root))
    }

    @Test("Guessing needs both markers - CLAUDE.md alone is some other project")
    func guessingNeedsBothMarkers() throws {
        let claudeOnly = try TempRepo(prefix: "repo-check-marker", skill: false)
        try "# Some other project\n".write(
            to: claudeOnly.root.appendingPathComponent(PrincipleRepo.markerRelativePath),
            atomically: true,
            encoding: .utf8)

        // The gate a turn passes and the test used to guess are deliberately
        // different: guessing wrong is worse than not guessing.
        #expect(!PrincipleRepo.isPrincipleRepo(at: claudeOnly.root))
        #expect(!PrincipleRepo.hasAskRaySkill(at: claudeOnly.root))
    }

    // MARK: - Probing candidates (KTD5)

    @Test("Probing takes the first real repo and skips what is only nearly one")
    func probingPicksTheFirstValidCandidate() throws {
        // The real home directory is never read here; the list is injected.
        let missing = try TempRepo(prefix: "cand-missing", create: false)
        let bare = try TempRepo(prefix: "cand-bare", skill: false)
        let real = try TempRepo(prefix: "cand-real")
        let second = try TempRepo(prefix: "cand-second")

        let found = RepoLocation.firstPrincipleRepo(
            in: [missing.root.path, bare.root.path, real.root.path, second.root.path])
        #expect(found?.path == real.root.path)
    }

    @Test("No candidate is the repo - nothing is guessed")
    func probingGuessesNothingWhenNoCandidateFits() throws {
        let bare = try TempRepo(prefix: "cand-bare", skill: false)
        let missing = try TempRepo(prefix: "cand-missing", create: false)

        #expect(RepoLocation.firstPrincipleRepo(in: [bare.root.path, missing.root.path]) == nil)
        #expect(RepoLocation.firstPrincipleRepo(in: []) == nil)
    }

    @Test("The shipped candidate list is where the repo lives, expanded not left as a tilde")
    func wellKnownCandidatesAreExpanded() {
        #expect(RepoLocation.wellKnownCandidates.first == "~/Documents/Projects/Principle")
        #expect(RepoLocation.wellKnownCandidates.allSatisfy { $0.hasPrefix("~/") })
        // A GUI app has no shell to expand the tilde, so the probe does it.
        let first = AppSettings.expandedURL(RepoLocation.wellKnownCandidates[0])
        #expect(first.path == NSHomeDirectory() + "/Documents/Projects/Principle")
        #expect(!first.path.contains("~"))
    }

    @Test("A configured path still wins over any candidate")
    func configuredPathWins() throws {
        let configured = try TempRepo(prefix: "cand-configured")
        let candidate = try TempRepo(prefix: "cand-other")
        let suiteName = "com.danny.principle.tests.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(configured.root.path, forKey: AppSettings.Key.repoPath)

        let resolved = RepoLocation.current(defaults: defaults, candidates: [candidate.root.path])
        #expect(resolved.path == configured.root.path)
    }
}
