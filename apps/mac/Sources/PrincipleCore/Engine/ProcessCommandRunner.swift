import Foundation

/// Runs a short command to completion and hands back what it printed.
/// Only for the cheap probes (`--version`, `auth status`); a streaming turn goes
/// through `EngineService`.
public struct ProcessCommandRunner: CommandRunning {
    /// Guards against a probe that never returns holding the UI hostage.
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 10) {
        self.timeout = timeout
    }

    public func run(executable: URL, arguments: [String]) throws -> CommandOutput {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        // Nothing to type at these commands; an inherited terminal would let the
        // CLI block on a prompt instead of reporting a status.
        process.standardInput = FileHandle.nullDevice

        try process.run()

        // Drain both pipes off-thread: a probe that fills the 64K pipe buffer would
        // otherwise deadlock against `waitUntilExit`.
        let collected = PipeCollector(output: output, errors: errors)
        collected.start()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        // A probe that ignores SIGTERM would otherwise keep the timeout it just
        // blew, since `waitUntilExit` below waits for it however long it takes.
        if process.isRunning {
            ProcessTermination.terminate(process)
        }
        process.waitUntilExit()
        let (out, err) = collected.wait()
        return CommandOutput(status: process.terminationStatus, standardOutput: out, standardError: err)
    }
}

/// Reads two pipes to EOF on background threads.
private final class PipeCollector: @unchecked Sendable {
    private let output: Pipe
    private let errors: Pipe
    private let group = DispatchGroup()
    private var out = Data()
    private var err = Data()

    init(output: Pipe, errors: Pipe) {
        self.output = output
        self.errors = errors
    }

    func start() {
        read(output.fileHandleForReading) { self.out = $0 }
        read(errors.fileHandleForReading) { self.err = $0 }
    }

    func wait() -> (String, String) {
        group.wait()
        return (String(decoding: out, as: UTF8.self), String(decoding: err, as: UTF8.self))
    }

    /// A dedicated thread rather than the global pool: this blocks until EOF, and
    /// parking blocking work in the shared pool starves everything else.
    private func read(_ handle: FileHandle, into store: @escaping @Sendable (Data) -> Void) {
        group.enter()
        Thread.detachNewThread { [group] in
            defer { group.leave() }
            store(handle.readDataToEndOfFile())
        }
    }
}
