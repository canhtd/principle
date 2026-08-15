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
        ///
        /// `Task` is deliberately absent. The ask-ray skill offers to hand the
        /// judgment to a Fable subagent and to farm the corpus grep out to a cheap
        /// one; both are right in a chat window and wrong here, because the user
        /// picked the model in the app's own model picker and a nested run pays
        /// for a second engine startup before it can answer. See
        /// `ConsultPrompt.systemPrompt`, which tells the engine the same thing in
        /// words so it does not waste a turn asking for a tool it cannot have.
        public var allowedTools: [String]
        /// Belt to the allowlist's braces: named here, `Task` is gone from the
        /// engine's own manifest, so the model never sees it as an option.
        public var disallowedTools: [String]
        public var permissionMode: String
        /// KTD1 watchdog: silence longer than this means hung. Shortened in tests.
        public var silenceTimeout: TimeInterval

        public init(
            allowedTools: [String] = [
                "Read", "Grep", "Glob", "Write", "Edit", "Bash(grep:*)", "Bash(python3:*)",
            ],
            disallowedTools: [String] = ["Task", "Workflow"],
            permissionMode: String = "acceptEdits",
            silenceTimeout: TimeInterval = 300
        ) {
            self.allowedTools = allowedTools
            self.disallowedTools = disallowedTools
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
    ///
    /// `--include-partial-messages` is what makes the answer readable while it is
    /// still being written. Without it the CLI emits an `assistant` message only
    /// once the whole message is finished, and this app's turn ends with a long
    /// document being composed — measured on a fixture consult, the first word of
    /// the answer reached the screen 96 s in, at the same instant as the last.
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
            "--include-partial-messages",
            "--permission-mode", configuration.permissionMode,
        ]
        if let resumeID, !resumeID.isEmpty {
            arguments += ["--resume", resumeID]
        }
        arguments += extraArgs
        if !configuration.disallowedTools.isEmpty {
            arguments += ["--disallowedTools", configuration.disallowedTools.joined(separator: " ")]
        }
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
