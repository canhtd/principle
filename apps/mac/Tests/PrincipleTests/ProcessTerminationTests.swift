import Foundation
import Testing

@testable import PrincipleCore

/// Spawns a shell that runs `script` and says nothing.
private func spawn(_ script: String) throws -> Process {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", script]
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    return process
}

private func waitForFile(_ url: URL, timeout: TimeInterval = 5) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if FileManager.default.fileExists(atPath: url.path) { return true }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return FileManager.default.fileExists(atPath: url.path)
}

/// SIGTERM is a request. A wedged engine can refuse it, and then the pipes stay
/// open and the turn hangs forever — so the escalation to SIGKILL is what makes
/// "stop this process" mean something.
@Suite("Process termination")
struct ProcessTerminationTests {
    @Test("Tiến trình phớt lờ SIGTERM vẫn chết trong khung ân hạn")
    func aProcessIgnoringSIGTERMIsKilled() async throws {
        let dir = try TempRepo(prefix: "kill")
        let ready = dir.root.appendingPathComponent("ready")
        // The ready file is written *after* the trap, so the SIGTERM below is
        // guaranteed to land on a process that ignores it.
        let process = try spawn("trap '' TERM; : > '\(ready.path)'; sleep 30")
        #expect(await waitForFile(ready))

        let start = Date()
        ProcessTermination.terminate(process, graceSeconds: 0.5)
        process.waitUntilExit()
        let elapsed = Date().timeIntervalSince(start)

        #expect(!process.isRunning)
        #expect(elapsed < 3)
        #expect(process.terminationReason == .uncaughtSignal)
        #expect(process.terminationStatus == SIGKILL)
    }

    @Test("Tiến trình nghe lời chết ngay, không phải chờ hết khung ân hạn")
    func aCooperativeProcessDiesOnSIGTERMWithoutWaitingOutTheGrace() throws {
        let process = try spawn("sleep 30")

        let start = Date()
        ProcessTermination.terminate(process, graceSeconds: 5)
        process.waitUntilExit()

        #expect(Date().timeIntervalSince(start) < 2)
        #expect(process.terminationReason == .uncaughtSignal)
        #expect(process.terminationStatus == SIGTERM)
    }

    @Test("Tiến trình đã xong thì không làm gì thêm")
    func anAlreadyExitedProcessIsLeftAlone() throws {
        let process = try spawn("exit 3")
        process.waitUntilExit()

        ProcessTermination.terminate(process)

        #expect(process.terminationStatus == 3)
        #expect(process.terminationReason == .exit)
    }
}
