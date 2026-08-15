import Foundation

/// Spawns the `claude` CLI for one turn and streams its events back (KTD1).
///
/// The CLI, not an embedded Agent SDK: no extra runtime to ship, and everything the
/// app relies on (skills, subagents, `--resume`) is behaviour that was probed against
/// this exact binary.
public final class EngineService: @unchecked Sendable {
    public struct Configuration: Sendable {
        /// Under `acceptEdits` in print mode anything outside this list is refused.
        /// It covers exactly the corpus/memory recipe in CLAUDE.md and the skill.
        public var allowedTools: [String]
        public var permissionMode: String
        /// KTD1 watchdog: silence longer than this means hung. Shortened in tests.
        public var silenceTimeout: TimeInterval

        public init(
            allowedTools: [String] = [
                "Read", "Grep", "Glob", "Task", "Write", "Edit", "Bash(grep:*)", "Bash(python3:*)",
            ],
            permissionMode: String = "acceptEdits",
            silenceTimeout: TimeInterval = 300
        ) {
            self.allowedTools = allowedTools
            self.permissionMode = permissionMode
            self.silenceTimeout = silenceTimeout
        }
    }

    private let executableURL: URL
    private let configuration: Configuration
    private let lock = NSLock()
    private var runs: [ObjectIdentifier: EngineRun] = [:]

    /// `executableURL` is always absolute — see `EngineBinaryResolver`.
    public init(executableURL: URL, configuration: Configuration = Configuration()) {
        self.executableURL = executableURL
        self.configuration = configuration
    }

    /// Runs one turn. Pass `resumeID` from the previous turn's `RunResult` to keep
    /// the engine's context; `extraArgs` carries per-turn flags such as
    /// `--append-system-prompt`.
    public func send(
        prompt: String,
        model: String,
        resumeID: String? = nil,
        cwd: URL,
        extraArgs: [String] = []
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let arguments = Self.arguments(
                model: model,
                resumeID: resumeID,
                extraArgs: extraArgs,
                configuration: configuration
            )
            let box = RunBox()
            let run = EngineRun(
                executableURL: executableURL,
                arguments: arguments,
                cwd: cwd,
                prompt: prompt,
                silenceTimeout: configuration.silenceTimeout,
                continuation: continuation
            ) { [weak self] in
                if let run = box.value { self?.forget(run) }
            }
            box.value = run
            remember(run)
            // A consumer that stops iterating (Task cancelled, `break`) must not
            // leave a CLI process alive.
            continuation.onTermination = { reason in
                if case .cancelled = reason { run.cancel() }
            }
            run.start()
        }
    }

    /// Stops every turn in flight — what the Stop button calls.
    public func cancel() {
        lock.lock()
        let inFlight = Array(runs.values)
        lock.unlock()
        inFlight.forEach { $0.cancel() }
    }

    /// True while at least one spawned process is alive.
    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return runs.values.contains { $0.isRunning }
    }

    /// The command shape verified against the CLI. `--allowedTools` goes last
    /// because it is variadic: anything positional after it gets swallowed.
    static func arguments(
        model: String,
        resumeID: String?,
        extraArgs: [String],
        configuration: Configuration
    ) -> [String] {
        var arguments = [
            "-p",
            "--model", model,
            "--output-format", "stream-json",
            "--verbose",
            "--permission-mode", configuration.permissionMode,
        ]
        if let resumeID, !resumeID.isEmpty {
            arguments += ["--resume", resumeID]
        }
        arguments += extraArgs
        arguments += ["--allowedTools", configuration.allowedTools.joined(separator: " ")]
        return arguments
    }

    private func remember(_ run: EngineRun) {
        lock.lock()
        runs[ObjectIdentifier(run)] = run
        lock.unlock()
    }

    private func forget(_ run: EngineRun) {
        lock.lock()
        runs[ObjectIdentifier(run)] = nil
        lock.unlock()
    }
}

/// Lets the run's completion callback refer back to the run that owns it.
private final class RunBox: @unchecked Sendable {
    var value: EngineRun?
}
