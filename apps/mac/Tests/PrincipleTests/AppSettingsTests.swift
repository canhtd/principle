import Foundation
import Testing

@testable import PrincipleCore

/// A defaults domain nobody else owns. The real suite is the one the shipping
/// app writes to — a test must never touch it.
private final class TempSuite {
    let name = "com.danny.principle.tests.\(UUID().uuidString)"

    var defaults: UserDefaults { UserDefaults(suiteName: name)! }
    var settings: AppSettings { AppSettings(suiteName: name) }

    deinit { UserDefaults().removePersistentDomain(forName: name) }
}

/// A throwaway repo root, so a repo-path test never points at the real `memory/`.
private final class TempDir {
    let root: URL

    init(create: Bool = true) throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("principle-settings-\(UUID().uuidString)", isDirectory: true)
        if create {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
    }

    deinit { try? FileManager.default.removeItem(at: root) }
}

@Suite("AppSettings")
struct AppSettingsTests {
    // MARK: - 1. Response model (KTD8, AE4)

    @Test("Nothing stored means Fable 5, and a new session draft starts there")
    func defaultModelIsFable() throws {
        let suite = TempSuite()

        #expect(suite.settings.responseModel == ModelAlias.fable)
        #expect(ModelAlias.displayName(suite.settings.responseModel) == "Fable 5")
        #expect(suite.settings.newSessionDraft().model == ModelAlias.fable)
        #expect(AppSettings.responseModel(in: suite.defaults) == ModelAlias.fable)
    }

    @Test("Only the response model is mapped - the app never names a subagent tier")
    func onlyTwoAliasesAreOffered() {
        #expect(AppSettings.selectableModels == [ModelAlias.fable, ModelAlias.opus])
        #expect(ModelAlias.displayName(ModelAlias.opus) == "Opus 5")
    }

    @Test("A stored alias the app no longer offers falls back instead of reaching the CLI")
    func unknownStoredModelFallsBack() throws {
        let suite = TempSuite()
        suite.defaults.set("gpt-9", forKey: AppSettings.Key.responseModel)

        #expect(suite.settings.responseModel == ModelAlias.fable)
    }

    @Test("Choosing Opus 5 carries alias 'opus' all the way into the spawn arguments")
    @MainActor
    func opusReachesTheSpawnPath() async throws {
        let suite = TempSuite()
        let repo = try TempDir()

        var settings = suite.settings
        settings.responseModel = ModelAlias.opus
        // Written through: the next read of the shared suite, in any process,
        // sees the choice.
        #expect(suite.settings.responseModel == ModelAlias.opus)

        let store = SessionStore(repoURL: repo.root)
        let engine = MockTurnEngine(responses: [.script(events: [])])
        let model = SessionViewModel(
            engine: engine,
            store: store,
            availabilityProvider: StubAvailabilityProvider(value: .ready(version: "2.1.233"))
        )
        var draft = suite.settings.newSessionDraft()
        draft.topic = "Có nên đổi việc"
        #expect(draft.model == ModelAlias.opus)
        model.createSession(from: draft)

        await model.send("Câu hỏi đầu tiên")

        #expect(engine.calls.count == 1)
        #expect(engine.calls.first?.model == ModelAlias.opus)
        // The CLI takes the alias verbatim as `--model`.
        let arguments = EngineService.arguments(
            model: engine.calls.first?.model ?? "",
            resumeID: nil,
            extraArgs: [],
            configuration: EngineService.Configuration()
        )
        #expect(arguments.contains("opus"))
    }

    @Test("A session already on disk keeps the model it was created with")
    @MainActor
    func existingSessionKeepsItsModel() async throws {
        let suite = TempSuite()
        let repo = try TempDir()
        let store = SessionStore(repoURL: repo.root)
        let existing = try store.create(topic: "Ca cũ", model: ModelAlias.fable)

        var settings = suite.settings
        settings.responseModel = ModelAlias.opus

        let engine = MockTurnEngine(responses: [.script(events: [])])
        let model = SessionViewModel(
            engine: engine,
            store: store,
            availabilityProvider: StubAvailabilityProvider(value: .ready(version: "2.1.233"))
        )
        model.select(existing.id)

        await model.send("Tiếp tục ca cũ")

        #expect(engine.calls.first?.model == ModelAlias.fable)
    }

    // MARK: - 2. Repo path

    @Test("A configured repo path is what RepoLocation and the store use")
    func repoPathMovesTheStore() throws {
        let suite = TempSuite()
        let repo = try TempDir()
        var settings = suite.settings
        settings.repoPath = repo.root.path

        #expect(RepoLocation.current(defaults: suite.defaults).path == repo.root.path)
        #expect(settings.repoURL.path == repo.root.path)
        #expect(settings.repoPathStatus == .valid)
        #expect(settings.repoPathWarning == nil)

        let store = SessionStore(repoURL: settings.repoURL)
        #expect(store.sessionsDirectory.path.hasPrefix(repo.root.path))
        let session = try store.create(topic: "Ca trong repo mới", model: ModelAlias.default)
        #expect(try store.load(id: session.id).topic == "Ca trong repo mới")
    }

    @Test("A tilde is expanded against the home directory, not left as a literal folder name")
    func tildeIsExpanded() throws {
        let suite = TempSuite()
        var settings = suite.settings
        settings.repoPath = "~/Documents/Principle"

        #expect(settings.repoURL.path == NSHomeDirectory() + "/Documents/Principle")
        #expect(RepoLocation.current(defaults: suite.defaults).path == settings.repoURL.path)
    }

    @Test("A repo path that is not there is flagged, and reading it still does not crash")
    func missingRepoPathIsFlagged() throws {
        let suite = TempSuite()
        let repo = try TempDir(create: false)
        var settings = suite.settings
        settings.repoPath = repo.root.path

        #expect(settings.repoPathStatus == .missing)
        #expect(settings.repoPathWarning != nil)
        // Still the configured path: silently swapping in a fallback would hide
        // the typo the warning is there to show.
        #expect(settings.repoURL.path == repo.root.path)
        #expect(try SessionStore(repoURL: settings.repoURL).loadAllWithReport().sessions.isEmpty)
    }

    @Test("A repo path pointing at a file is flagged as not a folder")
    func fileRepoPathIsFlagged() throws {
        let suite = TempSuite()
        let repo = try TempDir()
        let file = repo.root.appendingPathComponent("CLAUDE.md")
        try "x".write(to: file, atomically: true, encoding: .utf8)

        var settings = suite.settings
        settings.repoPath = file.path

        #expect(settings.repoPathStatus == .notAFolder)
        #expect(settings.repoPathWarning != nil)
    }

    @Test("An empty repo path is not an error - it just means the built-in location")
    func emptyRepoPathIsUnset() throws {
        let suite = TempSuite()
        var settings = suite.settings
        settings.repoPath = "   "

        #expect(settings.repoPathStatus == .unset)
        #expect(settings.repoPathWarning == nil)
        #expect(AppSettings.repoPath(in: suite.defaults) == nil)
        // Whitespace must not be stored as if it were a path.
        #expect(RepoLocation.current(defaults: suite.defaults).path != "   ")
    }

    // MARK: - 3. Binary override (KTD4, R5)

    @Test("An override resolves to exactly that executable, never a candidate")
    func overrideResolvesExactly() throws {
        let suite = TempSuite()
        let box = try FakeBinaries()
        defer { box.cleanUp() }
        let candidate = try box.makeExecutable(named: "claude", in: "brew")
        let override = try box.makeExecutable(named: "claude", in: "custom")

        var settings = suite.settings
        settings.claudeBinaryOverride = override.path

        #expect(AppSettings.claudeBinaryOverride(in: suite.defaults) == override.path)
        #expect(settings.resolvedBinary(candidates: [candidate.path])?.path == override.path)
        #expect(settings.binaryOverrideWarning == nil)

        let checker = EngineAvailabilityChecker(candidates: [candidate.path], runner: StubRunner.loggedIn)
        #expect(checker.check(overridePath: settings.engineOverridePath) == .ready(version: "2.1.233"))
    }

    @Test("An empty override falls back to the candidate list")
    func emptyOverrideUsesCandidates() throws {
        let suite = TempSuite()
        let box = try FakeBinaries()
        defer { box.cleanUp() }
        let candidate = try box.makeExecutable(named: "claude", in: "brew")

        let settings = suite.settings
        #expect(settings.engineOverridePath == nil)
        #expect(settings.resolvedBinary(candidates: [candidate.path])?.path == candidate.path)
        #expect(settings.binaryOverrideWarning == nil)
    }

    @Test("An override pointing at nothing warns in Settings and stays not-installed")
    func missingOverrideWarns() throws {
        let suite = TempSuite()
        let box = try FakeBinaries()
        defer { box.cleanUp() }
        let candidate = try box.makeExecutable(named: "claude", in: "brew")

        var settings = suite.settings
        settings.claudeBinaryOverride = box.path("nowhere/claude")

        #expect(settings.resolvedBinary(candidates: [candidate.path]) == nil)
        #expect(settings.binaryOverrideWarning != nil)
        let checker = EngineAvailabilityChecker(candidates: [candidate.path], runner: StubRunner.loggedIn)
        #expect(checker.check(overridePath: settings.engineOverridePath) == .notInstalled)
    }

    @Test("The Settings probe reports through the override path")
    func probeUsesTheOverride() async throws {
        let suite = TempSuite()
        let box = try FakeBinaries()
        defer { box.cleanUp() }
        let binary = try box.makeExecutable(named: "claude", in: "custom")

        var settings = suite.settings
        settings.claudeBinaryOverride = binary.path

        let probe = settings.availabilityProbe(
            checker: EngineAvailabilityChecker(candidates: [], runner: StubRunner.loggedIn)
        )
        #expect(await probe.currentAvailability() == .ready(version: "2.1.233"))
    }

    // MARK: - 4. The shared domain (KTD5)

    @Test("Values persist in the suite, so `swift run` and the bundled app agree")
    func valuesPersistInTheSuite() throws {
        let suite = TempSuite()
        var settings = suite.settings
        settings.responseModel = ModelAlias.opus
        settings.repoPath = "/tmp/principle-repo"
        settings.claudeBinaryOverride = "/tmp/claude"

        // A second reader of the same domain sees all three.
        let reread = suite.settings
        #expect(reread.responseModel == ModelAlias.opus)
        #expect(reread.repoPath == "/tmp/principle-repo")
        #expect(reread.claudeBinaryOverride == "/tmp/claude")

        // Clearing a field removes it rather than storing an empty string.
        settings.repoPath = ""
        #expect(suite.defaults.string(forKey: AppSettings.Key.repoPath) == nil)
        #expect(suite.settings.repoPathStatus == .unset)
    }

    @Test("The shipping app and the dev run read the same domain")
    func sharedSuiteIsTheBundleIdentifier() {
        #expect(AppSettings.defaultsSuite == "com.danny.principle")
        #expect(AppSettings.defaultsSuite == PrincipleInfo.bundleIdentifier)
        #expect(RepoLocation.defaultsSuite == AppSettings.defaultsSuite)
        #expect(AppSettings.sharedDefaults() != nil)
    }
}
