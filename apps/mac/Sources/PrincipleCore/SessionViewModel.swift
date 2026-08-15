import Foundation
import Observation
import os

/// Everything the chat window shows and does: the session list, the turn in
/// flight, and whether the engine can run one at all.
///
/// Lives in the library rather than next to the views so the whole flow —
/// event → progress line → persisted transcript — is testable with a scripted
/// engine and a temp directory.
@MainActor
@Observable
public final class SessionViewModel {
    // MARK: - Sessions

    public private(set) var sessions: [ChatSession] = []
    /// Session files that could not be read; surfaced instead of silently dropped.
    public private(set) var skippedFiles: [SkippedSessionFile] = []
    public private(set) var selectedSessionID: UUID?

    // MARK: - Turn in flight

    public internal(set) var phase: TurnPhase = .idle
    /// Answer text received so far. Cleared once the turn is persisted.
    public internal(set) var streamingText = ""
    /// The session the running turn belongs to — the selection can move while
    /// the engine works, and the answer must land where it was asked.
    public internal(set) var activeSessionID: UUID?
    public internal(set) var errorMessage: String?
    /// `nil` until the first check has run.
    public private(set) var availability: EngineAvailability?

    /// The composer's text. Public setter: it is a plain two-way binding.
    public var draft = ""

    let engine: any TurnRunning
    let store: SessionStore
    /// Where a consult gets filed: `memory/cases/` plus the index line in
    /// `memory/MEMORY.md`. The app writes both, from the trailer's `case`.
    let caseFiles: CaseFileStore
    /// The local principle corpus (KTD3). Loaded once: a repo without the file
    /// simply renders no cards.
    public let corpus: CorpusStore
    /// The book's own paragraphs, picked out of that same corpus and sent with
    /// every turn as the cadence to answer in.
    let voice: VoiceExemplars
    private let availabilityProvider: any EngineAvailabilityProviding
    /// Kept so "Resend" retries the same question without asking it twice.
    var lastPrompt: String?

    static let logger = Logger(subsystem: PrincipleInfo.bundleIdentifier, category: "SessionViewModel")

    public init(
        engine: any TurnRunning,
        store: SessionStore,
        availabilityProvider: any EngineAvailabilityProviding,
        corpus: CorpusStore? = nil
    ) {
        self.engine = engine
        self.store = store
        caseFiles = CaseFileStore(repoURL: store.repoURL)
        self.availabilityProvider = availabilityProvider
        // Defaults to the corpus that sits in the same repo as the sessions.
        let loaded = corpus ?? CorpusStore(repoURL: store.repoURL)
        self.corpus = loaded
        voice = VoiceExemplars(corpus: loaded)
        refreshSessions()
    }

    /// The wiring the app runs with. Kept here so the executable target stays
    /// `@main` plus views (KTD5).
    public static func live(repoURL: URL = RepoLocation.current(), binaryOverride: String? = nil) -> SessionViewModel {
        // No binary on disk means every send is blocked by the availability
        // check below, so this placeholder is never actually spawned — it only
        // lets the window open and explain itself (AE5).
        let binary = EngineBinaryResolver.resolve(override: binaryOverride)
            ?? URL(fileURLWithPath: "/nonexistent/claude")
        return SessionViewModel(
            engine: EngineService(executableURL: binary),
            store: SessionStore(repoURL: repoURL),
            availabilityProvider: EngineAvailabilityProbe(overridePath: binaryOverride)
        )
    }

    // MARK: - Derived state

    public var currentSession: ChatSession? {
        sessions.first { $0.id == selectedSessionID }
    }

    /// What the sidebar draws (R1). Derived: `sessions` is the only state, so a
    /// turn that updates one session cannot leave the day list behind.
    public var groups: [SessionDayGroup] { store.groupedByDay(sessions) }

    public var messages: [ChatMessage] { currentSession?.messages ?? [] }

    /// The model of *this* session, for the chat header (AE4).
    public var modelLabel: String {
        "Model: \(ModelAlias.displayName(currentSession?.model ?? ModelAlias.default))"
    }

    public var statusLine: String? { phase.statusLine }

    /// The answer as it should read while it is still streaming: the trailer is
    /// addressed to the app, never to the reader (KTD3).
    public var visibleStreamingText: String {
        TrailerParser.visibleText(streaming: streamingText)
    }

    /// True while the running turn belongs to the session on screen.
    public var isShowingActiveTurn: Bool {
        activeSessionID != nil && activeSessionID == selectedSessionID
    }

    public var canStop: Bool { phase.isStreaming }

    public var canSend: Bool {
        !phase.isStreaming && selectedSessionID != nil && !isEngineBlocked
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var canResend: Bool {
        !phase.isStreaming && errorMessage != nil && lastPrompt != nil && selectedSessionID != nil
    }

    // MARK: - Engine availability (KTD4, AE5)

    public var isEngineBlocked: Bool {
        guard let availability else { return false }
        if case .ready = availability { return false }
        return true
    }

    /// What to tell the user when the engine cannot run.
    public var engineGuidance: String? { availability?.guidance }

    public func refreshAvailability() async {
        // Gated on the repo too: a perfectly good engine still cannot run the
        // consultation from a directory that has no `ask-ray` skill in it.
        availability = await availabilityProvider.currentAvailability().gated(onRepoAt: store.repoURL)
    }

    // MARK: - Session list

    /// Re-reads every session file. For launch and for changes made from outside
    /// the app — a turn of its own updates the list from what the store handed
    /// back, without walking the directory again.
    public func refreshSessions() {
        do {
            let report = try store.loadAllWithReport()
            sessions = report.sessions
            skippedFiles = report.skipped
            reconcileSelection()
        } catch {
            errorMessage = "Could not read the session list: \(error.localizedDescription)"
            Self.logger.error("Loading sessions failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Takes in a session the store just wrote. What it returned is exactly what
    /// landed on disk, so re-reading the whole directory would only cost a turn
    /// its responsiveness.
    func apply(_ session: ChatSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        reconcileSelection()
    }

    /// Keeps the selection on a session that still exists, falling back to the
    /// newest one when there is nothing selected.
    private func reconcileSelection() {
        if let selected = selectedSessionID, !sessions.contains(where: { $0.id == selected }) {
            selectedSessionID = nil
        }
        if selectedSessionID == nil {
            selectedSessionID = groups.first?.sessions.first?.id
        }
    }

    public func select(_ id: UUID?) {
        guard id != selectedSessionID else { return }
        selectedSessionID = id
        // The old session's failure is not this session's problem.
        if !phase.isStreaming { errorMessage = nil }
    }

    /// Two-way binding for the sidebar's `List(selection:)`.
    public var selection: UUID? {
        get { selectedSessionID }
        set { select(newValue) }
    }

    @discardableResult
    public func createSession(topic: String, model: String = ModelAlias.default) throws -> ChatSession {
        let session = try store.create(topic: topic, model: model)
        apply(session)
        select(session.id)
        return session
    }

    /// What the sheet calls: a failed write becomes a message on screen rather
    /// than an error the view has to know how to phrase.
    public func createSession(from draft: NewSessionDraft) {
        guard draft.canCreate else { return }
        do {
            try createSession(topic: draft.trimmedTopic, model: draft.model)
        } catch {
            errorMessage = "Could not create the session: \(error.localizedDescription)"
            Self.logger.error("Creating a session failed: \(String(describing: error), privacy: .public)")
        }
    }
}
