import Foundation

/// Stopping a spawned process for good.
///
/// `Process.terminate()` only sends SIGTERM, which a wedged engine is free to
/// ignore — and while it ignores it the pipes stay open, so `readDataToEndOfFile`
/// and `waitUntilExit` never return and the turn hangs forever. Every place that
/// stops a process goes through here, so the escalation is written once.
enum ProcessTermination {
    /// How long a process gets to honour SIGTERM before SIGKILL settles it.
    static let defaultGrace: TimeInterval = 1.5

    /// SIGTERM, then SIGKILL if the process is still alive `graceSeconds` later.
    ///
    /// Blocks the calling thread for at most the grace window — a cooperative
    /// process returns in milliseconds. Call it from a background thread; a
    /// caller on the main actor must hand it off first.
    static func terminate(_ process: Process, graceSeconds: TimeInterval = defaultGrace) {
        guard process.isRunning else { return }
        // Read the pid before the process is reaped: `processIdentifier` is only
        // meaningful while the child exists.
        let pid = process.processIdentifier
        process.terminate()

        let deadline = Date().addingTimeInterval(graceSeconds)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        guard process.isRunning, pid > 0 else { return }
        kill(pid, SIGKILL)
    }
}
