import Foundation
import Testing

@testable import PrincipleCore

/// Every test writes into a throwaway repo under the system temp dir and never
/// spawns a real engine.
private final class TempRepoDir {
    let root: URL

    init() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("principle-vm-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    var store: SessionStore { SessionStore(repoURL: root) }

    deinit { try? FileManager.default.removeItem(at: root) }
}

@MainActor
private func makeViewModel(
    repo: TempRepoDir,
    engine: MockTurnEngine,
    availability: EngineAvailability = .ready(version: "2.1.233"),
    existing: ChatSession? = nil
) throws -> SessionViewModel {
    let model = SessionViewModel(
        engine: engine,
        store: repo.store,
        availabilityProvider: StubAvailabilityProvider(value: availability)
    )
    if let existing {
        try repo.store.save(existing)
        model.refreshSessions()
        model.select(existing.id)
    } else {
        try model.createSession(topic: "Ca thử", model: ModelAlias.default)
    }
    return model
}

private func toolUse(_ description: String, inSubagent: Bool = false) -> StreamEvent {
    .toolUse(ToolUse(id: "tool-1", name: "Grep", description: description, isInSubagent: inSubagent))
}

private func sessionStarted(_ id: String) -> StreamEvent {
    .sessionStarted(SessionInit(sessionID: id, model: "fable", cwd: nil, tools: [], skills: ["ask-ray"]))
}

private func result(_ id: String, text: String) -> StreamEvent {
    .result(RunResult(sessionID: id, isError: false, text: text, subtype: "success"))
}

@MainActor
@Suite("SessionViewModel")
struct SessionViewModelTests {
    // MARK: - 1. Progress mapping (KTD7)

    @Test("init → tool_use → text → result đưa trạng thái đi đúng thứ tự")
    func phasesProgressThroughATurn() async throws {
        let repo = try TempRepoDir()
        let engine = MockTurnEngine()
        let model = try makeViewModel(repo: repo, engine: engine)

        let turn = Task { await model.send("Tôi nên chọn hướng nào?") }
        #expect(await waitUntil { engine.hasLiveStream })

        var observed: [TurnPhase] = [model.phase]
        engine.emit(sessionStarted("eng-1"))
        #expect(await waitUntil { model.phase == .preparing })
        observed.append(model.phase)

        engine.emit(toolUse("Tra nguyên tắc trong corpus"))
        #expect(await waitUntil { model.phase == .runningTool("Tra nguyên tắc trong corpus") })
        observed.append(model.phase)

        engine.emit(.text("Bắt đầu từ chẩn đoán.", inSubagent: false))
        #expect(await waitUntil { model.phase == .answering })
        observed.append(model.phase)
        #expect(model.streamingText == "Bắt đầu từ chẩn đoán.")

        engine.emit(result("eng-1", text: "Bắt đầu từ chẩn đoán."))
        engine.finish()
        await turn.value

        #expect(
            observed == [.preparing, .preparing, .runningTool("Tra nguyên tắc trong corpus"), .answering])
        #expect(model.phase == .idle)
        #expect(model.statusLine == nil)
        #expect(model.messages.map(\.role) == [.user, .assistant])
        #expect(model.messages.last?.text == "Bắt đầu từ chẩn đoán.")
        // The engine's own id is persisted so the next turn can --resume (KTD2).
        #expect(model.currentSession?.claudeSessionID == "eng-1")
        #expect(model.streamingText.isEmpty)
    }

    // MARK: - 2. Subagent (R6)

    @Test("Event trong subagent hiện trạng thái tra cứu, không đổ vào câu trả lời")
    func subagentEventsShowLookupStatus() async throws {
        let repo = try TempRepoDir()
        let engine = MockTurnEngine()
        let model = try makeViewModel(repo: repo, engine: engine)

        let turn = Task { await model.send("Ca này xử lý sao?") }
        #expect(await waitUntil { engine.hasLiveStream })

        engine.emit(toolUse("Tra corpus", inSubagent: true))
        #expect(await waitUntil { model.phase == .subagent })
        #expect(model.statusLine == "Đang tra cứu (subagent)…")

        engine.emit(.text("ghi chú nội bộ của subagent", inSubagent: true))
        #expect(await waitUntil { model.phase == .subagent })
        #expect(model.streamingText.isEmpty)

        engine.finish()
        await turn.value
    }

    // MARK: - 3. Error + resend

    @Test("Turn lỗi hiện thông báo và cho gửi lại, không nhân đôi câu hỏi")
    func failedTurnOffersResend() async throws {
        let repo = try TempRepoDir()
        let engine = MockTurnEngine(responses: [
            .script(events: [sessionStarted("eng-1")], failure: EngineError.failed(message: "Engine bó tay.")),
            .script(events: [result("eng-2", text: "Xong rồi.")]),
        ])
        let model = try makeViewModel(repo: repo, engine: engine)

        await model.send("Tôi kẹt chuyện tiền bạc.")
        #expect(model.phase == .idle)
        #expect(model.errorMessage == "Engine bó tay.")
        #expect(model.canResend)
        #expect(model.messages.map(\.role) == [.user])

        await model.resend()
        #expect(model.errorMessage == nil)
        #expect(!model.canResend)
        #expect(engine.calls.count == 2)
        #expect(engine.calls.map(\.prompt) == ["Tôi kẹt chuyện tiền bạc.", "Tôi kẹt chuyện tiền bạc."])
        // The question is asked once even though the turn ran twice.
        #expect(model.messages.map(\.role) == [.user, .assistant])
        #expect(model.messages.last?.text == "Xong rồi.")
    }

    // MARK: - 4. Engine chưa đăng nhập (AE5)

    @Test("Engine đăng xuất thì chặn gửi và hiện màn hình trạng thái")
    func loggedOutBlocksSend() async throws {
        let repo = try TempRepoDir()
        let engine = MockTurnEngine()
        let guidance = EngineAvailabilityChecker.loggedOutGuidance
        let model = try makeViewModel(repo: repo, engine: engine, availability: .loggedOut(guidance: guidance))

        await model.send("Hỏi thử khi chưa đăng nhập.")

        #expect(engine.calls.isEmpty)
        #expect(model.isEngineBlocked)
        #expect(model.engineGuidance == guidance)
        #expect(model.errorMessage == guidance)
        #expect(model.phase == .idle)
        #expect(model.messages.isEmpty)
    }

    // MARK: - 5. Nút Dừng

    @Test("Dừng chỉ bật khi đang stream, huỷ engine và giữ phần đã nhận")
    func stopCancelsAndKeepsPartialText() async throws {
        let repo = try TempRepoDir()
        let engine = MockTurnEngine()
        let model = try makeViewModel(repo: repo, engine: engine)
        #expect(!model.canStop)

        let turn = Task { await model.send("Kể tôi nghe cách chẩn đoán.") }
        #expect(await waitUntil { engine.hasLiveStream })

        engine.emit(sessionStarted("eng-1"))
        engine.emit(.text("Phần đã kịp trả lời", inSubagent: false))
        #expect(await waitUntil { model.streamingText == "Phần đã kịp trả lời" })
        #expect(model.canStop)

        model.stop()
        await turn.value

        #expect(engine.cancelCount == 1)
        #expect(model.phase == .idle)
        #expect(!model.canStop)
        #expect(model.errorMessage == nil)
        #expect(model.messages.last?.text == "Phần đã kịp trả lời")
        #expect(model.currentSession?.claudeSessionID == "eng-1")
    }

    // MARK: - 6. NewSessionSheet (R1)

    @Test("Nút Tạo tắt khi chủ đề rỗng hoặc toàn khoảng trắng")
    func newSessionRequiresATopic() {
        var draft = NewSessionDraft()
        #expect(!draft.canCreate)

        draft.topic = "    \n\t "
        #expect(!draft.canCreate)

        draft.topic = "  Bỏ thuốc lá  "
        #expect(draft.canCreate)
        #expect(draft.trimmedTopic == "Bỏ thuốc lá")
    }

    // MARK: - 7. Resume chết → chạy lại một lần có seed (KTD2)

    @Test("Resume id mồ côi bị xoá và turn chạy lại một lần như phiên mới có seed")
    func deadResumeRetriesOnceWithSeed() async throws {
        let repo = try TempRepoDir()
        let engine = MockTurnEngine(responses: [
            .script(
                events: [],
                failure: EngineError.exited(code: 1, message: "No conversation found with session ID dead-1")),
            .script(events: [result("eng-9", text: "Trả lời sau khi seed.")]),
        ])
        let existing = ChatSession(
            topic: "Bỏ thuốc lá",
            model: ModelAlias.default,
            claudeSessionID: "dead-1",
            messages: [
                ChatMessage(role: .user, text: "Tôi hút một gói mỗi ngày."),
                ChatMessage(role: .assistant, text: "Bắt đầu từ chẩn đoán."),
            ])
        let model = try makeViewModel(repo: repo, engine: engine, existing: existing)

        await model.send("Hôm nay tôi lại hút.")

        #expect(engine.calls.count == 2)
        #expect(engine.calls[0].resumeID == "dead-1")
        #expect(engine.calls[0].prompt == "Hôm nay tôi lại hút.")
        #expect(engine.calls[1].resumeID == nil)
        let seeded = engine.calls[1].prompt
        #expect(seeded.contains(TranscriptSeed.header))
        #expect(seeded.contains("Tôi hút một gói mỗi ngày."))
        #expect(seeded.contains("Bắt đầu từ chẩn đoán."))
        #expect(seeded.hasSuffix("Hôm nay tôi lại hút."))
        // The question itself is not duplicated inside the seed block.
        #expect(seeded.components(separatedBy: "Hôm nay tôi lại hút.").count == 2)

        #expect(model.errorMessage == nil)
        #expect(model.currentSession?.claudeSessionID == "eng-9")
        #expect(model.messages.last?.text == "Trả lời sau khi seed.")
    }

    @Test("Lỗi không phải session chết thì không chạy lại")
    func unrelatedFailureDoesNotRetry() async throws {
        let repo = try TempRepoDir()
        let engine = MockTurnEngine(responses: [
            .script(events: [], failure: EngineError.hung(silence: 300))
        ])
        let existing = ChatSession(
            topic: "Ca cũ",
            model: ModelAlias.default,
            claudeSessionID: "alive-1",
            messages: [ChatMessage(role: .user, text: "Câu hỏi cũ.")])
        let model = try makeViewModel(repo: repo, engine: engine, existing: existing)

        await model.send("Câu hỏi mới.")

        #expect(engine.calls.count == 1)
        #expect(model.canResend)
        #expect(model.errorMessage?.contains("treo") == true)
        #expect(model.currentSession?.claudeSessionID == "alive-1")
    }

    // MARK: - 8. Header model (AE4)

    @Test("Header chat hiện model của phiên bằng tiếng Việt")
    func headerShowsSessionModel() throws {
        let repo = try TempRepoDir()
        let engine = MockTurnEngine()
        let model = try makeViewModel(repo: repo, engine: engine)
        #expect(model.modelLabel == "Model: Fable 5")

        try model.createSession(topic: "Ca dùng Opus", model: ModelAlias.opus)
        #expect(model.modelLabel == "Model: Opus 5")
    }

    // MARK: - 9. Sidebar (R1)

    @Test("Sidebar nhóm phiên theo ngày, mới nhất lên đầu")
    func sidebarGroupsByDay() throws {
        let repo = try TempRepoDir()
        let engine = MockTurnEngine()
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        try repo.store.save(ChatSession(topic: "Ca hôm qua", createdAt: yesterday, model: ModelAlias.default))
        try repo.store.save(ChatSession(topic: "Ca hôm nay", createdAt: today, model: ModelAlias.default))

        let model = SessionViewModel(
            engine: engine,
            store: repo.store,
            availabilityProvider: StubAvailabilityProvider(value: .ready(version: "2.1.233")))
        model.refreshSessions()

        #expect(model.groups.count == 2)
        #expect(model.groups.first?.sessions.first?.topic == "Ca hôm nay")
        #expect(model.groups.last?.sessions.first?.topic == "Ca hôm qua")
    }

    // MARK: - 10. Principle cards (KTD3)

    @Test("Kết thúc lượt: trailer bị tách khỏi transcript, id vào principle_ids")
    func turnFilesCitedPrincipleIDs() async throws {
        let repo = try TempRepoDir()
        let engine = MockTurnEngine(responses: [
            .script(events: [
                sessionStarted("eng-1"),
                result("eng-1", text: "Bắt đầu từ chẩn đoán.\nPRINCIPLES_JSON: {\"ids\":[\"life:5.6\",\"work:2.1\"]}"),
            ])
        ])
        let model = try makeViewModel(repo: repo, engine: engine)

        await model.send("Tôi nên chọn hướng nào?")

        let answer = try #require(model.messages.last)
        #expect(answer.role == .assistant)
        #expect(answer.text == "Bắt đầu từ chẩn đoán.")
        #expect(answer.principleIDs == ["life:5.6", "work:2.1"])
        // Persisted, so reopening the session re-renders the cards offline.
        #expect(try repo.store.load(id: #require(model.selectedSessionID)).messages.last?.principleIDs
            == ["life:5.6", "work:2.1"])
    }

    @Test("Không có trailer → không id nào được ghi, text nguyên vẹn")
    func turnWithoutATrailerFilesNoIDs() async throws {
        let repo = try TempRepoDir()
        let engine = MockTurnEngine(responses: [
            .script(events: [sessionStarted("eng-1"), result("eng-1", text: "Chưa trích nguyên tắc nào.")])
        ])
        let model = try makeViewModel(repo: repo, engine: engine)

        await model.send("Tôi nên chọn hướng nào?")

        #expect(model.messages.last?.text == "Chưa trích nguyên tắc nào.")
        #expect(model.messages.last?.principleIDs.isEmpty == true)
    }

    @Test("Thẻ chỉ dựng từ corpus: id lạ không sinh thẻ nào")
    func cardsComeOnlyFromTheCorpus() throws {
        let repo = try TempRepoDir()
        let corpus = CorpusStore(records: [
            PrincipleRecord(
                id: "life:5.6",
                part: "Nguyên tắc sống",
                chapter: "Chương 5",
                num: "5.6",
                title: "[FIXTURE] Tiêu đề",
                body: "[FIXTURE] Thân bài",
                hasBody: true)
        ])
        let model = SessionViewModel(
            engine: MockTurnEngine(),
            store: repo.store,
            availabilityProvider: StubAvailabilityProvider(value: .ready(version: "2.1.233")),
            corpus: corpus)

        let cited = ChatMessage(role: .assistant, text: "Trả lời.", principleIDs: ["life:5.6", "life:999.9"])
        #expect(model.principles(for: cited).map(\.id) == ["life:5.6"])
        #expect(model.principles(for: ChatMessage(role: .assistant, text: "Trả lời.")).isEmpty)
    }
}
