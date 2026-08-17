import Foundation
import Testing

@testable import PrincipleCore

/// The seam between the trailer and `memory/cases/`: the engine dictates the
/// case, the app writes it. `CaseFileStoreTests` covers what lands on disk; what
/// is worth pinning down here is that a real turn reaches the store at all, that
/// the path is remembered on the session, and that nothing in the filing can
/// cost the answer.
@MainActor
@Suite("SessionViewModel — ghi file ca")
struct SessionViewModelCaseTests {
    private static let trailer = """
        PRINCIPLES_JSON: {"diagnosis":{"kind":"Ca ưu tiên","why":"Mục tiêu chưa xếp hạng."},\
        "principles":[{"id":"life:5.6","apply":"Bạn đang cân cảm giác, chưa cân giá trị kỳ vọng."}],\
        "case":{"slug":"chon-giua-hai-loi-moi","problem":"Em phải chọn giữa hai lời mời.",\
        "real_problem":"Em chưa gọi tên thứ mình muốn.","direction":"Viết ra ba thứ bạn muốn nhất. Rồi chấm hai nơi theo đúng ba thứ đó.",\
        "price":"Mất một buổi tối, và phải thừa nhận tiền không đứng đầu.","flip":"Ba thứ đó chấm ra kết quả ngang nhau.",\
        "follow_up":"2026-08-22","goal":"—","continues":"—"}}
        """

    /// Today in the reader's own calendar, which is the one the store files by.
    private var today: String { CaseDocument.day(Date()) }

    private func makeModel(_ repo: TempRepo, _ engine: MockTurnEngine) throws -> SessionViewModel {
        let model = SessionViewModel(
            engine: engine,
            store: repo.sessions,
            availabilityProvider: StubAvailabilityProvider(value: .ready(version: "2.1.233")),
            corpus: CorpusStore(records: [])
        )
        try model.createSession(topic: "Ca thử", model: ModelAlias.default)
        return model
    }

    /// Drives one whole turn and hands back once the answer has been filed.
    ///
    /// Waits on the call count rather than on `hasLiveStream`: the mock keeps the
    /// finished continuation of the previous turn, so on a second turn the flag
    /// is already true and the events would be handed to a stream nobody reads.
    private func runTurn(_ model: SessionViewModel, _ engine: MockTurnEngine, _ answer: String) async {
        let before = engine.calls.count
        let turn = Task { await model.send("Em nên chọn nơi nào?") }
        #expect(await waitUntil { engine.calls.count > before })
        engine.emit(.result(RunResult(sessionID: "eng-1", isError: false, text: answer, subtype: "success")))
        engine.finish()
        await turn.value
    }

    @Test("Lượt đầu ghi file ca, thêm dòng index, và nhớ đường dẫn trên session")
    func theFirstTurnFilesTheCase() async throws {
        let repo = try TempRepo(prefix: "vm-case")
        try repo.writeMemory(TempRepo.memoryWithCaseIndex)
        let engine = MockTurnEngine()
        let model = try makeModel(repo, engine)

        await runTurn(model, engine, "Hãy gọi tên thứ bạn muốn trước đã.\n" + Self.trailer)

        let expected = "memory/cases/\(today)-chon-giua-hai-loi-moi.md"
        #expect(model.errorMessage == nil)
        #expect(model.currentSession?.caseFilePath == expected)
        // Persisted, not just held in memory: the next launch resumes this case.
        let sessionID = try #require(model.currentSession?.id)
        #expect(try repo.sessions.load(id: sessionID).caseFilePath == expected)

        let text = try repo.fileText(at: expected)
        #expect(text.contains("Em phải chọn giữa hai lời mời."))
        #expect(text.contains("Viết ra ba thứ bạn muốn nhất."))
        // Exactly one line, appended under the cases already listed.
        let indexLine = "- \(today) · [chon-giua-hai-loi-moi](cases/\(today)-chon-giua-hai-loi-moi.md)"
            + " · Ca ưu tiên · Viết ra ba thứ bạn muốn nhất · mở (follow-up 2026-08-22)"
        #expect(try repo.memoryText() == TempRepo.memoryWithCaseIndex + indexLine + "\n")
        // The answer itself is untouched by the filing — the trailer never shows.
        #expect(model.messages.last?.text == "Hãy gọi tên thứ bạn muốn trước đã.")
    }

    /// One consult is one case file. The system prompt rides every resume turn,
    /// so without this the second turn would open a second case for the same
    /// conversation and the index would double over a consult.
    @Test("Lượt sau ghi thêm vào đúng file ca đó, không thêm file hay dòng index thứ hai")
    func aResumeTurnAppendsToTheSameFile() async throws {
        let repo = try TempRepo(prefix: "vm-case-resume")
        try repo.writeMemory(TempRepo.memoryWithCaseIndex)
        let engine = MockTurnEngine()
        let model = try makeModel(repo, engine)
        await runTurn(model, engine, "Hãy gọi tên thứ bạn muốn trước đã.\n" + Self.trailer)
        let filed = try #require(model.currentSession?.caseFilePath)
        let indexAfterFirstTurn = try repo.memoryText()

        await runTurn(
            model, engine,
            """
            Hạn lùi ba tuần thì có chỗ để đo.
            PRINCIPLES_JSON: {"principles":[{"id":"life:5.6","apply":"Vẫn là giá trị kỳ vọng."}],\
            "case":{"slug":"chon-giua-hai-loi-moi","direction":"Dùng ba tuần đó thử việc ở nơi B một ngày.",\
            "flip":"Nơi B từ chối cho thử."}}
            """)

        let text = try repo.fileText(at: filed)
        #expect(text.contains("## Cập nhật \(today)"))
        #expect(text.contains("Dùng ba tuần đó thử việc ở nơi B một ngày."))
        #expect(text.contains("**Điều kiện lật:** Nơi B từ chối cho thử."))
        // What the first turn settled is still above the update.
        #expect(text.contains("Viết ra ba thứ bạn muốn nhất."))
        #expect(try repo.memoryText() == indexAfterFirstTurn)
        #expect(repo.caseFileNames.count == 1)
        #expect(model.currentSession?.caseFilePath == filed)
    }

    /// An answer whose trailer carries no case files nothing, exactly as one with
    /// no principles draws no cards — and the answer is kept either way (AE2).
    @Test("Trailer không có `case` thì không ghi file nào, câu trả lời vẫn giữ")
    func aTurnWithoutACaseFilesNothing() async throws {
        let repo = try TempRepo(prefix: "vm-case-none")
        let engine = MockTurnEngine()
        let model = try makeModel(repo, engine)

        await runTurn(
            model, engine,
            "Chưa đủ dữ kiện để chốt.\nPRINCIPLES_JSON: {\"principles\":[{\"id\":\"life:5.6\",\"apply\":\"Ở đây.\"}]}")

        #expect(model.errorMessage == nil)
        #expect(model.currentSession?.caseFilePath == nil)
        #expect(repo.caseFileNames.isEmpty)
        #expect(model.messages.last?.text == "Chưa đủ dữ kiện để chốt.")
    }

    /// The case file the session remembers is gone — deleted by hand between two
    /// turns. Filing says so on screen; what it must not do is lose the answer.
    @Test("File ca biến mất giữa hai lượt → báo lỗi, câu trả lời vẫn được lưu")
    func aMissingCaseFileReportsWithoutLosingTheAnswer() async throws {
        let repo = try TempRepo(prefix: "vm-case-gone")
        let engine = MockTurnEngine()
        let model = try makeModel(repo, engine)
        await runTurn(model, engine, "Hãy gọi tên thứ bạn muốn trước đã.\n" + Self.trailer)
        let filed = try #require(model.currentSession?.caseFilePath)
        try FileManager.default.removeItem(
            at: filed.split(separator: "/").reduce(repo.root) { $0.appendingPathComponent(String($1)) })

        await runTurn(model, engine, "Vẫn giữ hướng cũ.\n" + Self.trailer)

        #expect(model.errorMessage?.contains("case file") == true)
        #expect(model.messages.last?.text == "Vẫn giữ hướng cũ.")
        // No second case opened behind the reader's back.
        #expect(repo.caseFileNames.isEmpty)
    }
}
