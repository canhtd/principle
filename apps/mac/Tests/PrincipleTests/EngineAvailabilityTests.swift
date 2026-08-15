import Foundation
import Testing

@testable import PrincipleCore

@Suite("engine availability")
struct EngineAvailabilityTests {
    // MARK: - Binary resolution (never via inherited PATH)

    @Test("The first candidate that exists wins")
    func firstExistingCandidateWins() throws {
        let box = try FakeBinaries()
        defer { box.cleanUp() }
        let second = try box.makeExecutable(named: "claude", in: "second")
        let third = try box.makeExecutable(named: "claude", in: "third")

        let candidates = [box.path("missing/claude"), second.path, third.path]
        let resolved = EngineBinaryResolver.resolve(override: nil, candidates: candidates)
        #expect(resolved?.path == second.path)
    }

    @Test("An override path is used instead of the candidates")
    func overrideWins() throws {
        let box = try FakeBinaries()
        defer { box.cleanUp() }
        let candidate = try box.makeExecutable(named: "claude", in: "brew")
        let override = try box.makeExecutable(named: "claude", in: "custom")

        let resolved = EngineBinaryResolver.resolve(override: override.path, candidates: [candidate.path])
        #expect(resolved?.path == override.path)
    }

    @Test("No candidate on disk resolves to nothing, and the checker says not installed")
    func noCandidateResolvesToNil() throws {
        let box = try FakeBinaries()
        defer { box.cleanUp() }
        let candidates = [box.path("a/claude"), box.path("b/claude")]

        #expect(EngineBinaryResolver.resolve(override: nil, candidates: candidates) == nil)
        let checker = EngineAvailabilityChecker(candidates: candidates, runner: StubRunner())
        #expect(checker.check() == .notInstalled)
    }

    @Test("A non-executable file or a directory is not a usable binary")
    func onlyExecutableFilesResolve() throws {
        let box = try FakeBinaries()
        defer { box.cleanUp() }
        let plain = try box.makeFile(named: "claude", in: "plain", executable: false)
        let directory = try box.makeDirectory("dir/claude")

        #expect(EngineBinaryResolver.resolve(override: plain.path, candidates: []) == nil)
        #expect(EngineBinaryResolver.resolve(override: directory.path, candidates: []) == nil)
    }

    @Test("A tilde candidate expands against the home directory, not a shell")
    func tildeIsExpanded() {
        let expanded = EngineBinaryResolver.expand("~/.local/bin/claude")
        #expect(expanded == NSHomeDirectory() + "/.local/bin/claude")
        #expect(!expanded.contains("~"))
        #expect(EngineBinaryResolver.defaultCandidates.first == "~/.local/bin/claude")
    }

    @Test("An override pointing at nothing is not installed - no silent fallback")
    func missingOverrideIsNotInstalled() throws {
        let box = try FakeBinaries()
        defer { box.cleanUp() }
        // A perfectly good candidate exists; the bad override must still lose.
        let candidate = try box.makeExecutable(named: "claude", in: "brew")
        let checker = EngineAvailabilityChecker(candidates: [candidate.path], runner: StubRunner.loggedIn)

        #expect(checker.check(overridePath: box.path("nowhere/claude")) == .notInstalled)
    }

    // MARK: - `--version` + `auth status`

    @Test("Version plus a logged-in auth status is ready")
    func loggedInIsReady() throws {
        let box = try FakeBinaries()
        defer { box.cleanUp() }
        let binary = try box.makeExecutable(named: "claude", in: "bin")
        let checker = EngineAvailabilityChecker(candidates: [binary.path], runner: StubRunner.loggedIn)

        #expect(checker.check() == .ready(version: "2.1.233"))
    }

    @Test("loggedIn false gives Vietnamese guidance, not a dead end")
    func loggedOutCarriesGuidance() throws {
        let box = try FakeBinaries()
        defer { box.cleanUp() }
        let binary = try box.makeExecutable(named: "claude", in: "bin")
        let runner = StubRunner(responses: [
            "--version": CommandOutput(status: 0, standardOutput: "2.1.233 (Claude Code)\n"),
            "auth status": CommandOutput(
                status: 0, standardOutput: "{\"loggedIn\":false,\"subscriptionType\":\"none\"}\n"),
        ])
        let checker = EngineAvailabilityChecker(candidates: [binary.path], runner: runner)

        guard case .loggedOut(let guidance) = checker.check() else {
            Issue.record("expected .loggedOut")
            return
        }
        #expect(guidance.contains("đăng nhập"))
        #expect(guidance.contains("claude login"))
    }

    @Test("A binary that cannot report a version counts as not installed")
    func brokenBinaryIsNotInstalled() throws {
        let box = try FakeBinaries()
        defer { box.cleanUp() }
        let binary = try box.makeExecutable(named: "claude", in: "bin")
        let runner = StubRunner(responses: ["--version": CommandOutput(status: 127, standardError: "boom")])

        #expect(EngineAvailabilityChecker(candidates: [binary.path], runner: runner).check() == .notInstalled)
    }

    @Test("Unreadable auth output blocks the send instead of guessing")
    func unparseableAuthBlocks() throws {
        let box = try FakeBinaries()
        defer { box.cleanUp() }
        let binary = try box.makeExecutable(named: "claude", in: "bin")
        let runner = StubRunner(responses: [
            "--version": CommandOutput(status: 0, standardOutput: "2.1.233\n"),
            "auth status": CommandOutput(status: 0, standardOutput: "usage: claude auth ..."),
        ])

        guard case .loggedOut(let guidance) = EngineAvailabilityChecker(candidates: [binary.path], runner: runner).check()
        else {
            Issue.record("expected .loggedOut")
            return
        }
        #expect(!guidance.isEmpty)
    }

    @Test("auth JSON is found even with chatter around it")
    func authJSONIsExtracted() {
        #expect(EngineAvailabilityChecker.loggedIn(inJSON: "noise\n{\"loggedIn\":true}\nmore") == true)
        #expect(EngineAvailabilityChecker.loggedIn(inJSON: "{\"loggedIn\":false}") == false)
        #expect(EngineAvailabilityChecker.loggedIn(inJSON: "") == nil)
        #expect(EngineAvailabilityChecker.loggedIn(inJSON: "{broken") == nil)
        #expect(EngineAvailabilityChecker.loggedIn(inJSON: "{\"other\":1}") == nil)
    }

    @Test("Version string is the bare number, not the whole banner")
    func versionIsTrimmed() {
        #expect(EngineAvailabilityChecker.version(from: "2.1.233 (Claude Code)\n") == "2.1.233")
        #expect(EngineAvailabilityChecker.version(from: " 3.0.0 \n") == "3.0.0")
    }
}

