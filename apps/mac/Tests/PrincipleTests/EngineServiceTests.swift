import Foundation
import Testing

@testable import PrincipleCore

/// No test here talks to a real engine. Every "engine" is a shell script in a temp
/// directory that prints canned stream-json lines, so the spawn path, the line
/// framing, the watchdog and cancellation are all exercised for real without a
/// model call.
@Suite("engine service")
struct EngineServiceTests {
    // MARK: - Command shape (KTD1)

    @Test("First turn carries the flags the CLI was verified with")
    func firstTurnArguments() {
        let arguments = EngineService.arguments(
            model: "fable", resumeID: nil, extraArgs: [], configuration: .init())

        #expect(arguments.prefix(2) == ["-p", "--model"])
        #expect(arguments.contains("fable"))
        #expect(consecutive(arguments, "--output-format", "stream-json"))
        #expect(arguments.contains("--verbose"))
        #expect(consecutive(arguments, "--permission-mode", "acceptEdits"))
        #expect(!arguments.contains("--resume"))
        // Variadic flag last so nothing positional can be swallowed.
        #expect(arguments[arguments.count - 2] == "--allowedTools")
        #expect(arguments.last == "Read Grep Glob Task Write Edit Bash(grep:*) Bash(python3:*)")
        // The prompt is never an argument; it goes over stdin.
        #expect(!arguments.contains { $0.hasPrefix("Xin chào") })
    }

    @Test("Later turns resume, and extra args land before the variadic flag")
    func resumeAndExtraArguments() {
        let arguments = EngineService.arguments(
            model: "opus",
            resumeID: "abc-123",
            extraArgs: ["--append-system-prompt", "in trailer"],
            configuration: .init()
        )

        #expect(consecutive(arguments, "--resume", "abc-123"))
        #expect(consecutive(arguments, "--append-system-prompt", "in trailer"))
        let allowedIndex = arguments.firstIndex(of: "--allowedTools") ?? -1
        let extraIndex = arguments.firstIndex(of: "--append-system-prompt") ?? -1
        #expect(extraIndex >= 0)
        #expect(extraIndex < allowedIndex)
    }

    @Test("An empty resume id is treated as a first turn")
    func emptyResumeIsIgnored() {
        let arguments = EngineService.arguments(
            model: "fable", resumeID: "", extraArgs: [], configuration: .init())
        #expect(!arguments.contains("--resume"))
    }

    // MARK: - Streaming

    @Test("A whole turn streams through in order and ends on result")
    func happyPathStreams() async throws {
        let engine = try FakeEngine(
            script: """
                cat > /dev/null
                printf '%s\\n' '{"type":"system","subtype":"init","session_id":"s-ok","tools":["Read"],"skills":["ask-ray"]}'
                printf '%s\\n' '{"type":"system","subtype":"hook_started","hook_id":"h"}'
                printf '%s\\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"xong"}]},"parent_tool_use_id":null}'
                printf '%s\\n' '{"type":"result","subtype":"success","is_error":false,"session_id":"s-ok","result":"xong"}'
                """)
        defer { engine.cleanUp() }

        let outcome = await engine.collect(prompt: "Xin chào")

        #expect(outcome.error == nil)
        #expect(outcome.events.count == 3)
        #expect(outcome.events.first?.sessionStarted?.sessionID == "s-ok")
        #expect(outcome.events.first?.sessionStarted?.skills == ["ask-ray"])
        #expect(outcome.events.last?.runResult?.sessionID == "s-ok")
        #expect(outcome.events.last?.runResult?.text == "xong")
    }

    @Test("The prompt reaches the process over stdin")
    func promptGoesOverStdin() async throws {
        let engine = try FakeEngine(
            script: """
                PROMPT=$(cat)
                printf '{"type":"result","subtype":"success","is_error":false,"session_id":"s","result":"%s"}\\n' "$PROMPT"
                """)
        defer { engine.cleanUp() }

        let outcome = await engine.collect(prompt: "toi muon bo thuoc la")
        #expect(outcome.events.last?.runResult?.text == "toi muon bo thuoc la")
    }

    @Test("A line split across two reads is still decoded once")
    func splitLinesAreReassembled() async throws {
        let engine = try FakeEngine(
            script: """
                cat > /dev/null
                printf '%s' '{"type":"result","subtype":"success","is_error":false,'
                sleep 0.2
                printf '%s\\n' '"session_id":"s-split","result":"ok"}'
                """)
        defer { engine.cleanUp() }

        let outcome = await engine.collect(prompt: "hi")
        #expect(outcome.events.count == 1)
        #expect(outcome.events.first?.runResult?.sessionID == "s-split")
    }

    @Test("result.is_error ends the stream with the engine's own message")
    func resultErrorSurfacesMessage() async throws {
        let engine = try FakeEngine(
            script: """
                cat > /dev/null
                printf '%s\\n' '{"type":"result","subtype":"error_during_execution","is_error":true,"session_id":"s-err","result":"No conversation found with session ID"}'
                """)
        defer { engine.cleanUp() }

        let outcome = await engine.collect(prompt: "hi")

        // The result event still arrives: the caller needs its session id.
        #expect(outcome.events.last?.runResult?.isError == true)
        #expect(outcome.error as? EngineError == .failed(message: "No conversation found with session ID"))
        #expect(outcome.error?.localizedDescription.contains("No conversation found") == true)
    }

    @Test("A process that dies without a result reports its exit code and stderr")
    func abnormalExitIsReported() async throws {
        let engine = try FakeEngine(
            script: """
                cat > /dev/null
                echo "command not found: claude" 1>&2
                exit 127
                """)
        defer { engine.cleanUp() }

        let outcome = await engine.collect(prompt: "hi")
        #expect(outcome.error as? EngineError == .exited(code: 127, message: "command not found: claude"))
    }

    @Test("A binary that is not there fails to launch instead of hanging")
    func launchFailureIsReported() async throws {
        let engine = try FakeEngine(script: "exit 0")
        defer { engine.cleanUp() }
        let service = EngineService(executableURL: engine.root.appendingPathComponent("nope"))

        let outcome = await FakeEngine.collect(
            stream: service.send(prompt: "hi", model: "haiku", cwd: engine.root))
        guard case .launchFailed = outcome.error as? EngineError else {
            Issue.record("expected .launchFailed, got \(String(describing: outcome.error))")
            return
        }
    }

    // MARK: - Watchdog (KTD1)

    @Test("Silence past the threshold kills the process and reports a stuck engine")
    func watchdogTerminatesHungProcess() async throws {
        let engine = try FakeEngine(
            script: """
                cat > /dev/null
                echo $$ > "\(FakeEngine.pidFileToken)"
                printf '%s\\n' '{"type":"system","subtype":"init","session_id":"s-hang","tools":[],"skills":[]}'
                while :; do sleep 1; done
                """,
            silenceTimeout: 0.6)
        defer { engine.cleanUp() }

        let outcome = await engine.collect(prompt: "hi")

        // The event that did arrive is kept; only the silence after it is fatal.
        #expect(outcome.events.first?.sessionStarted?.sessionID == "s-hang")
        #expect(outcome.error as? EngineError == .hung(silence: 0.6))
        #expect(outcome.error?.localizedDescription.contains("stuck") == true)
        #expect(engine.spawnedProcessIsGone)
        #expect(engine.service.isRunning == false)
    }

    // MARK: - Cancellation

    @Test("cancel() terminates the process and ends the stream without an error")
    func explicitCancelTerminatesProcess() async throws {
        let engine = try FakeEngine(script: FakeEngine.longRunningScript)
        defer { engine.cleanUp() }

        let stream = engine.service.send(prompt: "hi", model: "haiku", cwd: engine.root)
        let collector = Task { await FakeEngine.collect(stream: stream) }

        #expect(await engine.waitForSpawnedPID())
        engine.service.cancel()
        let outcome = await collector.value

        #expect(outcome.error == nil)
        #expect(outcome.events.first?.sessionStarted?.sessionID == "s-long")
        #expect(engine.spawnedProcessIsGone)
        #expect(engine.service.isRunning == false)
    }

    @Test("Cancelling the consuming task also terminates the process")
    func taskCancellationTerminatesProcess() async throws {
        let engine = try FakeEngine(script: FakeEngine.longRunningScript)
        defer { engine.cleanUp() }

        let stream = engine.service.send(prompt: "hi", model: "haiku", cwd: engine.root)
        let collector = Task { await FakeEngine.collect(stream: stream) }

        #expect(await engine.waitForSpawnedPID())
        collector.cancel()
        _ = await collector.value

        #expect(await engine.waitForProcessToDie())
    }

    private func consecutive(_ arguments: [String], _ flag: String, _ value: String) -> Bool {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return false }
        return arguments[index + 1] == value
    }
}

