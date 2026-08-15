import Foundation

/// The slice of `EngineService` the chat needs. Narrow on purpose: it is the
/// seam tests replace with a scripted stream, so it must not grow beyond what
/// running and stopping one turn requires.
public protocol TurnRunning: Sendable {
    func send(
        prompt: String,
        model: String,
        resumeID: String?,
        cwd: URL,
        extraArgs: [String]
    ) -> AsyncThrowingStream<StreamEvent, Error>

    func cancel()
}

extension EngineService: TurnRunning {}

/// KTD4 says availability is re-checked before every send. Behind a protocol so
/// the chat can be tested without a `claude` binary on disk.
public protocol EngineAvailabilityProviding: Sendable {
    func currentAvailability() async -> EngineAvailability
}

/// The real check, moved off the main actor: it spawns two short processes and
/// the UI must not freeze while they run.
public struct EngineAvailabilityProbe: EngineAvailabilityProviding {
    private let checker: EngineAvailabilityChecker
    private let overridePath: String?

    public init(checker: EngineAvailabilityChecker = EngineAvailabilityChecker(), overridePath: String? = nil) {
        self.checker = checker
        self.overridePath = overridePath
    }

    public func currentAvailability() async -> EngineAvailability {
        let checker = checker
        let overridePath = overridePath
        return await Task.detached(priority: .userInitiated) {
            checker.check(overridePath: overridePath)
        }.value
    }
}

/// Reads a failed turn to decide whether the engine simply lost the session we
/// asked it to resume (KTD2), in which case the app re-runs the turn once as a
/// fresh session seeded from the transcript it owns.
public enum TurnFailure {
    /// Only consulted for turns that actually passed `--resume`.
    public static func indicatesDeadSession(_ error: any Error) -> Bool {
        guard let error = error as? EngineError else { return false }
        switch error {
        case .failed(let message):
            return mentionsMissingSession(message)
        // A rejected `--resume` kills the CLI before any terminal event, often
        // with nothing on stderr — that shape alone is enough to retry once.
        case .exited(_, let message):
            return message.isEmpty || mentionsMissingSession(message)
        // A binary that will not launch, or one that went quiet, is not a
        // session problem: retrying without `--resume` would fail the same way.
        case .launchFailed, .hung:
            return false
        }
    }

    private static let subjects = ["session", "conversation", "phiên"]
    private static let complaints = [
        "not found", "no conversation", "unknown", "does not exist", "doesn't exist",
        "no longer", "invalid", "expired", "không tồn tại",
    ]

    private static func mentionsMissingSession(_ message: String) -> Bool {
        let text = message.lowercased()
        return subjects.contains { text.contains($0) } && complaints.contains { text.contains($0) }
    }
}
