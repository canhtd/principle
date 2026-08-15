import Foundation

@testable import PrincipleCore


/// A shell script pretending to be `claude`, plus the service wired to it.
final class FakeEngine {
    static let pidFileToken = "__PIDFILE__"

    /// Announces itself, records its pid, then never says anything again.
    static let longRunningScript = """
        cat > /dev/null
        echo $$ > "\(pidFileToken)"
        printf '%s\\n' '{"type":"system","subtype":"init","session_id":"s-long","tools":[],"skills":[]}'
        while :; do sleep 1; done
        """

    struct Outcome {
        var events: [StreamEvent] = []
        var error: Error?
    }

    let root: URL
    let service: EngineService
    private let pidFile: URL

    init(script: String, silenceTimeout: TimeInterval = 30) throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("principle-fake-engine-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        pidFile = root.appendingPathComponent("pid")

        let binary = root.appendingPathComponent("claude")
        let body = script.replacingOccurrences(of: Self.pidFileToken, with: pidFile.path)
        // The warm-up guard exists so `warmUp()` below can pay the first-exec cost.
        try "#!/bin/sh\n[ \"$1\" = \"--warmup\" ] && exit 0\n\(body)\n"
            .write(to: binary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        try Self.warmUp(binary)

        service = EngineService(
            executableURL: binary,
            configuration: .init(silenceTimeout: silenceTimeout))
    }

    /// macOS spends ~1s the first time it execs a freshly written file. Paying that
    /// here keeps the watchdog test measuring silence rather than launch latency.
    private static func warmUp(_ binary: URL) throws {
        let process = Process()
        process.executableURL = binary
        process.arguments = ["--warmup"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
    }

    func collect(prompt: String) async -> Outcome {
        await Self.collect(stream: service.send(prompt: prompt, model: "haiku", cwd: root))
    }

    static func collect(stream: AsyncThrowingStream<StreamEvent, Error>) async -> Outcome {
        var outcome = Outcome()
        do {
            for try await event in stream { outcome.events.append(event) }
        } catch {
            outcome.error = error
        }
        return outcome
    }

    /// The pid the script wrote for itself, once it has.
    var spawnedPID: pid_t? {
        guard let text = try? String(contentsOf: pidFile, encoding: .utf8) else { return nil }
        return pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// `kill(pid, 0)` fails once the process is gone and reaped.
    var spawnedProcessIsGone: Bool {
        guard let pid = spawnedPID else { return false }
        return kill(pid, 0) != 0
    }

    func waitForSpawnedPID(timeout: TimeInterval = 5) async -> Bool {
        await poll(timeout: timeout) { self.spawnedPID != nil }
    }

    func waitForProcessToDie(timeout: TimeInterval = 5) async -> Bool {
        await poll(timeout: timeout) { self.spawnedProcessIsGone }
    }

    private func poll(timeout: TimeInterval, until condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }

    func cleanUp() { try? FileManager.default.removeItem(at: root) }
}
