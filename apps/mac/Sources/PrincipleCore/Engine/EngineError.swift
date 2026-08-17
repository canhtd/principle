import Foundation

/// Why a turn ended badly. Messages are user-facing: the chat shows them on the
/// failed session and offers a resend, it never retries silently.
public enum EngineError: Error, Equatable, LocalizedError, Sendable {
    /// The process could not be started at all.
    case launchFailed(String)
    /// KTD1 watchdog: no new event for longer than the silence threshold.
    case hung(silence: TimeInterval)
    /// The engine finished with `result.is_error == true`.
    case failed(message: String)
    /// The process died without ever emitting a terminal `result`.
    case exited(code: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let reason):
            "Could not run Claude Code: \(reason)"
        case .hung(let silence):
            "The engine is stuck — nothing new for \(Self.duration(silence)). The turn was stopped; resend when you are ready."
        case .failed(let message):
            message.isEmpty ? "The engine reported an error with no details." : message
        case .exited(let code, let message):
            message.isEmpty
                ? "The engine exited unexpectedly (code \(code))."
                : "The engine exited unexpectedly (code \(code)): \(message)"
        }
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        if seconds >= 60 {
            let minutes = Int((seconds / 60).rounded())
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
        let whole = Int(seconds.rounded())
        return "\(whole) second\(whole == 1 ? "" : "s")"
    }
}
