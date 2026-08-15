import Foundation

/// One spawned `claude -p` process, from launch to terminal event.
///
/// Reading happens on a dedicated thread with blocking `availableData` reads rather
/// than a `readabilityHandler`: the handler fires on a shared queue and can race the
/// termination handler, which made "did the stream end before or after the last
/// line?" undecidable. A serial read loop makes the end-of-stream bookkeeping local.
final class EngineRun: @unchecked Sendable {
    private let process = Process()
    private let output = Pipe()
    private let errors = Pipe()
    private let input = Pipe()
    private let prompt: String
    private let silenceTimeout: TimeInterval
    private let continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation
    private let onFinish: @Sendable () -> Void

    private let lock = NSLock()
    private var lastActivity = Date()
    /// Set by the watchdog or by `cancel()`; the read loop consults it when deciding
    /// how the stream ends, so a terminated process is never reported as a crash.
    private var abort: Abort?
    private var didFinish = false
    private var watchdog: DispatchSourceTimer?
    private var capturedErrors = Data()
    /// Signalled when stderr has been read to EOF, so a failure message is never
    /// assembled from a half-read pipe.
    private let errorsDrained = DispatchSemaphore(value: 0)

    private enum Abort { case cancelled, hung }

    init(
        executableURL: URL,
        arguments: [String],
        cwd: URL,
        prompt: String,
        silenceTimeout: TimeInterval,
        continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation,
        onFinish: @escaping @Sendable () -> Void
    ) {
        self.prompt = prompt
        self.silenceTimeout = silenceTimeout
        self.continuation = continuation
        self.onFinish = onFinish
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = cwd
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
    }

    var isRunning: Bool { process.isRunning }

    func start() {
        do {
            try process.run()
        } catch {
            finish(with: .launchFailed(error.localizedDescription))
            return
        }
        lock.lock()
        // The silence clock starts when the engine does, not when this object was made.
        lastActivity = Date()
        lock.unlock()
        writePrompt()
        drainErrors()
        startWatchdog()
        // Dedicated threads, not `DispatchQueue.global`: all three jobs below block
        // for the lifetime of the turn, and parking them in the global pool starves
        // it — which showed up as the stdin write never happening.
        Thread.detachNewThread { [self] in readLoop() }
    }

    /// Stop the turn on purpose (user pressed Stop, or the consumer walked away).
    /// The stream ends normally — what already streamed stays in the transcript.
    func cancel() {
        lock.lock()
        if abort == nil { abort = .cancelled }
        lock.unlock()
        terminateProcess()
    }

    // MARK: - Plumbing

    /// The prompt goes over stdin, not as an argument: `--allowedTools` is variadic
    /// and swallows a trailing positional.
    private func writePrompt() {
        let handle = input.fileHandleForWriting
        let data = Data(prompt.utf8)
        Thread.detachNewThread {
            // Broken pipe if the engine died early — nothing to do but move on.
            try? handle.write(contentsOf: data)
            try? handle.close()
        }
    }

    private func drainErrors() {
        let handle = errors.fileHandleForReading
        Thread.detachNewThread { [self] in
            let data = handle.readDataToEndOfFile()
            lock.lock()
            capturedErrors = data
            lock.unlock()
            errorsDrained.signal()
        }
    }

    private func startWatchdog() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        let tick = max(0.05, silenceTimeout / 4)
        timer.schedule(deadline: .now() + tick, repeating: tick)
        timer.setEventHandler { [self] in
            lock.lock()
            let silent = Date().timeIntervalSince(lastActivity)
            let alreadyAborting = abort != nil
            if silent > silenceTimeout, !alreadyAborting { abort = .hung }
            let shouldKill = !alreadyAborting && silent > silenceTimeout
            lock.unlock()
            if shouldKill { terminateProcess() }
        }
        lock.lock()
        watchdog = timer
        lock.unlock()
        timer.resume()
    }

    private func readLoop() {
        let handle = output.fileHandleForReading
        var buffer = Data()
        var terminal: RunResult?
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = Data(buffer[buffer.startIndex..<newline])
                buffer = Data(buffer[buffer.index(after: newline)...])
                if let result = emit(line) { terminal = result }
            }
        }
        if !buffer.isEmpty, let result = emit(buffer) { terminal = result }
        process.waitUntilExit()
        finish(terminal: terminal)
    }

    /// Decodes one line, yields its events, and reports the terminal one if present.
    private func emit(_ line: Data) -> RunResult? {
        let events = StreamEventDecoder.events(fromLine: String(decoding: line, as: UTF8.self))
        guard !events.isEmpty else { return nil }
        lock.lock()
        lastActivity = Date()
        lock.unlock()
        var terminal: RunResult?
        for event in events {
            continuation.yield(event)
            if let result = event.runResult { terminal = result }
        }
        return terminal
    }

    /// On its own thread: the SIGTERM → SIGKILL escalation waits out a grace
    /// window, and `cancel()` is called from the main actor when the user
    /// presses Stop. The read loop is already parked on the pipe, so it picks
    /// up the EOF whenever the process actually dies.
    private func terminateProcess() {
        Thread.detachNewThread { [self] in ProcessTermination.terminate(process) }
    }

    private func finish(terminal: RunResult?) {
        // stderr hits EOF right after the process exits; the cap only guards against
        // a grandchild that inherited the pipe and outlived its parent.
        _ = errorsDrained.wait(timeout: .now() + 1)
        lock.lock()
        let abort = self.abort
        let stderr = String(decoding: capturedErrors, as: UTF8.self)
        lock.unlock()

        switch abort {
        case .hung:
            finish(with: .hung(silence: silenceTimeout))
        case .cancelled:
            finish(with: nil)
        case nil:
            if let terminal, terminal.isError {
                finish(with: .failed(message: terminal.text))
            } else if terminal == nil, process.terminationStatus != 0 {
                let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                finish(with: .exited(code: process.terminationStatus, message: String(message.suffix(500))))
            } else {
                finish(with: nil)
            }
        }
    }

    private func finish(with error: EngineError?) {
        lock.lock()
        guard !didFinish else { return lock.unlock() }
        didFinish = true
        let timer = watchdog
        watchdog = nil
        lock.unlock()

        timer?.cancel()
        continuation.finish(throwing: error)
        onFinish()
    }
}
