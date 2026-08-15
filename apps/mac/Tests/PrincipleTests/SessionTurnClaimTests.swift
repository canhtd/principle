import Foundation
import Testing

@testable import PrincipleCore

private func finished(_ id: String, text: String) -> StreamEvent {
    .result(RunResult(sessionID: id, isError: false, text: text, subtype: "success"))
}

/// The turn has to be claimed before the pre-send availability check suspends.
/// Both entry points guard on the phase, so while that check is in flight the
/// phase must already say a turn is running — otherwise a second tap sails
/// through the guard and the same question is asked twice.
///
/// The engine is scripted with a spare response on purpose: a duplicate turn
/// then finishes and the count says so, instead of the test hanging on a stream
/// nobody drives.
@MainActor
@Suite("Turn claim")
struct SessionTurnClaimTests {
    private func makeModel(
        repo: TempRepo,
        engine: MockTurnEngine,
        gate: GatedAvailabilityProvider
    ) throws -> SessionViewModel {
        let model = SessionViewModel(engine: engine, store: repo.sessions, availabilityProvider: gate)
        try model.createSession(topic: "Ca thử", model: ModelAlias.default)
        return model
    }

    @Test("Bấm Gửi lần hai trong lúc kiểm tra engine không mở thêm lượt nào")
    func aSecondSendDuringThePreflightIsIgnored() async throws {
        let repo = try TempRepo(prefix: "vm-claim")
        let engine = MockTurnEngine(responses: [
            .script(events: [finished("eng-1", text: "Xong.")]),
            .script(events: [finished("eng-2", text: "Lượt thừa.")]),
        ])
        let gate = GatedAvailabilityProvider(value: .ready(version: "2.1.233"), open: false)
        let model = try makeModel(repo: repo, engine: engine, gate: gate)

        model.draft = "Tôi nên chọn hướng nào?"
        let first = Task { await model.send("Tôi nên chọn hướng nào?") }
        #expect(await waitUntil { gate.calls == 1 })
        // Parked inside the check, and the turn is already claimed.
        #expect(model.phase == .preparing)
        #expect(!model.canSend)

        let second = Task { await model.send("Tôi nên chọn hướng nào?") }
        // The second tap must not even reach the availability check.
        #expect(!(await waitUntil(timeout: 0.3) { gate.calls > 1 }))

        gate.open()
        await first.value
        await second.value

        #expect(gate.calls == 1)
        #expect(engine.calls.count == 1)
        #expect(model.messages.map(\.role) == [.user, .assistant])
        #expect(model.messages.last?.text == "Xong.")
        #expect(model.phase == .idle)
    }

    @Test("Bấm Gửi lại lần hai trong lúc kiểm tra engine không chạy lại lượt")
    func aSecondResendDuringThePreflightIsIgnored() async throws {
        let repo = try TempRepo(prefix: "vm-claim")
        let engine = MockTurnEngine(responses: [
            .script(events: [], failure: EngineError.failed(message: "Engine bó tay.")),
            .script(events: [finished("eng-2", text: "Xong rồi.")]),
            .script(events: [finished("eng-3", text: "Lượt thừa.")]),
        ])
        let gate = GatedAvailabilityProvider(value: .ready(version: "2.1.233"))
        let model = try makeModel(repo: repo, engine: engine, gate: gate)

        await model.send("Tôi kẹt chuyện tiền bạc.")
        #expect(model.canResend)

        gate.close()
        let retry = Task { await model.resend() }
        #expect(await waitUntil { gate.calls == 2 })
        #expect(model.phase == .preparing)
        #expect(!model.canResend)

        let secondRetry = Task { await model.resend() }
        #expect(!(await waitUntil(timeout: 0.3) { gate.calls > 2 }))

        gate.open()
        await retry.value
        await secondRetry.value

        #expect(gate.calls == 2)
        #expect(engine.calls.count == 2)
        // The question was asked once even though the turn ran twice.
        #expect(model.messages.map(\.role) == [.user, .assistant])
        #expect(model.messages.last?.text == "Xong rồi.")
        #expect(model.phase == .idle)
    }

    @Test("Engine bị chặn thì trả lại phase idle và giữ nguyên câu đang soạn")
    func aBlockedEngineReleasesTheClaimAndKeepsTheDraft() async throws {
        let repo = try TempRepo(prefix: "vm-claim")
        let engine = MockTurnEngine()
        let guidance = EngineAvailabilityChecker.loggedOutGuidance
        let gate = GatedAvailabilityProvider(value: .loggedOut(guidance: guidance))
        let model = try makeModel(repo: repo, engine: engine, gate: gate)

        model.draft = "Hỏi thử khi chưa đăng nhập."
        await model.send(model.draft)

        #expect(model.phase == .idle)
        #expect(model.errorMessage == guidance)
        #expect(model.draft == "Hỏi thử khi chưa đăng nhập.")
        #expect(engine.calls.isEmpty)
    }
}
