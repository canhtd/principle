import Foundation
import Testing

@testable import PrincipleCore

/// Fixtures are invented, never the real translation: the real corpus is
/// gitignored for copyright while this file is committed.
private func record(
    id: String,
    part: String = "Nguyên tắc sống",
    chapter: String = "Chương 5 — Quyết định giả lập",
    num: String = "5.6",
    title: String = "[FIXTURE] Tiêu đề nguyên tắc",
    body: String = "",
    hasBody: Bool = false
) -> PrincipleRecord {
    PrincipleRecord(
        id: id, part: part, chapter: chapter, num: num, title: title, body: body, hasBody: hasBody
    )
}

/// What a principle card is made of before any of it is drawn: which label,
/// what is quotable, and whether the engine wrote a bridge into this case.
@Suite("PrincipleCardModel")
struct PrincipleCardModelTests {
    // MARK: - The red label

    @Test("Id life: → nhãn LIFE PRINCIPLE kèm số hiệu")
    func lifeLabel() {
        let card = PrincipleCardModel(record: record(id: "life:4.3e", num: "4.3e"))
        #expect(card.part == .life)
        #expect(card.label == "LIFE PRINCIPLE · 4.3e")
    }

    @Test("Id work: → nhãn WORK PRINCIPLE, không phụ thuộc chuỗi part")
    func workLabel() {
        let card = PrincipleCardModel(record: record(id: "work:13.5c", part: "", num: "13.5c"))
        #expect(card.part == .work)
        #expect(card.label == "WORK PRINCIPLE · 13.5c")
    }

    @Test("Id không có tiền tố → đọc từ chuỗi part tiếng Việt")
    func fallsBackToThePartText() {
        #expect(PrincipleCardModel(record: record(id: "5.6", part: "Nguyên tắc sống")).part == .life)
        #expect(
            PrincipleCardModel(record: record(id: "5.6", part: "Nguyên tắc làm việc")).part == .work
        )
    }

    @Test("Không xác định được nửa nào của sách → nhãn trung tính, không đoán")
    func unknownPartDoesNotGuess() {
        let card = PrincipleCardModel(record: record(id: "5.6", part: "", num: "5.6"))
        #expect(card.part == .unknown)
        #expect(card.label == "PRINCIPLE · 5.6")
    }

    @Test("Bản ghi không có số hiệu → nhãn không có dấu · thừa")
    func labelWithoutANumber() {
        #expect(PrincipleCardModel(record: record(id: "life:x", num: "")).label == "LIFE PRINCIPLE")
        #expect(PrincipleCardModel(record: record(id: "life:x", num: "  ")).label == "LIFE PRINCIPLE")
    }

    // MARK: - Quote and bridge (AE2, AE3)

    @Test("Bản ghi chỉ có tiêu đề → không có trích dẫn, thẻ vẫn mở được nếu có phần áp vào")
    func headingOnlyRecordHasNoQuote() {
        let card = PrincipleCardModel(record: record(id: "life:5.6"), apply: "[FIXTURE] Áp vào ca.")
        #expect(card.quote == nil)
        #expect(!card.hasQuote)
        #expect(card.hasApply)
        #expect(card.isExpandable)
    }

    @Test("Thân bài có sẵn → trích dẫn nguyên văn, cắt ở 40 từ")
    func quoteComesFromTheCorpus() throws {
        let body = (1...60).map { "từ\($0)" }.joined(separator: " ")
        let card = PrincipleCardModel(record: record(id: "life:5.6", body: body, hasBody: true))
        let quote = try #require(card.quote)
        #expect(quote.hasSuffix("từ40…"))
        #expect(card.hasQuote)
    }

    @Test("Phiên cũ không có phần áp vào ca → bỏ hẳn khối đó, không dựng chữ thay")
    func legacyCitationHasNoApply() {
        #expect(!PrincipleCardModel(record: record(id: "life:5.6")).hasApply)
        #expect(!PrincipleCardModel(record: record(id: "life:5.6"), apply: "").hasApply)
        #expect(!PrincipleCardModel(record: record(id: "life:5.6"), apply: "  \n ").hasApply)
    }

    @Test("Không có gì để mở → thẻ không mời mở ra")
    func headingOnlyWithoutApplyIsNotExpandable() {
        #expect(!PrincipleCardModel(record: record(id: "life:5.6")).isExpandable)
    }

    @Test("Phần áp vào ca được cắt khoảng trắng thừa nhưng giữ nguyên chữ")
    func applyIsTrimmedNotRewritten() {
        let card = PrincipleCardModel(record: record(id: "life:5.6"), apply: "  Anh đang đoán.\n")
        #expect(card.apply == "Anh đang đoán.")
    }

    // MARK: - Building the stack

    @Test("Thẻ giữ đúng thứ tự engine trích, tối đa 3")
    func cardsKeepCitationOrderAndCapAtThree() {
        let corpus = CorpusStore(records: (1...5).map { record(id: "life:\($0)", num: "\($0)") })
        let refs = ["life:3", "life:1", "life:5", "life:2"].map { PrincipleRef(id: $0, apply: "x") }

        let cards = PrincipleCardModel.cards(for: refs, corpus: corpus)

        #expect(cards.count == PrincipleCardModel.maxCards)
        #expect(cards.map(\.id) == ["life:3", "life:1", "life:5"])
    }

    @Test("Id corpus không biết → bỏ thẻ, và không ăn mất suất trong 3 thẻ (AE2)")
    func unknownIDsAreDroppedBeforeTheCap() {
        let corpus = CorpusStore(records: (1...4).map { record(id: "life:\($0)", num: "\($0)") })
        let refs = ["life:1", "life:404", "life:2", "life:3"].map { PrincipleRef(id: $0) }

        #expect(PrincipleCardModel.cards(for: refs, corpus: corpus).map(\.id) == ["life:1", "life:2", "life:3"])
    }

    @Test("Mỗi thẻ mang theo phần áp vào của đúng id đó")
    func eachCardCarriesItsOwnBridge() {
        let corpus = CorpusStore(records: [record(id: "life:1", num: "1"), record(id: "work:2", num: "2")])
        let cards = PrincipleCardModel.cards(
            for: [PrincipleRef(id: "life:1", apply: "A"), PrincipleRef(id: "work:2", apply: "B")],
            corpus: corpus
        )

        #expect(cards.map(\.apply) == ["A", "B"])
        #expect(cards.map(\.label) == ["LIFE PRINCIPLE · 1", "WORK PRINCIPLE · 2"])
    }

    @Test("Danh sách yêu thích: thẻ từ bản ghi trần, không có phần áp vào và không bị cắt còn 3")
    func cardsFromBareRecords() {
        let records = (1...5).map { record(id: "life:\($0)", num: "\($0)") }
        let cards = PrincipleCardModel.cards(for: records)

        #expect(cards.count == 5)
        #expect(cards.allSatisfy { !$0.hasApply })
    }
}

/// The other end of the same wire: what the chat window actually asks for.
@MainActor
@Suite("SessionViewModel.cards(for:)")
struct SessionViewModelCardsTests {
    @Test("Thẻ dựng từ trailer: id lạ bị bỏ, phần áp vào đi đúng thẻ của nó")
    func cardsResolveAgainstTheCorpus() throws {
        let repo = try TempRepo(prefix: "cards")
        let model = SessionViewModel(
            engine: MockTurnEngine(),
            store: repo.sessions,
            availabilityProvider: StubAvailabilityProvider(value: .ready(version: "2.1.233")),
            corpus: CorpusStore(records: [record(id: "life:5.6", body: "[FIXTURE] Thân bài", hasBody: true)])
        )

        let cited = ChatMessage(
            role: .assistant,
            text: "Trả lời.",
            principles: [PrincipleRef(id: "life:5.6", apply: "[FIXTURE] Áp vào ca."), PrincipleRef(id: "life:999.9")]
        )
        let cards = model.cards(for: cited)

        #expect(cards.map(\.id) == ["life:5.6"])
        #expect(cards.first?.apply == "[FIXTURE] Áp vào ca.")
        #expect(cards.first?.quote == "[FIXTURE] Thân bài")
        #expect(model.cards(for: ChatMessage(role: .assistant, text: "Trả lời.")).isEmpty)
    }
}
