import Foundation
import Testing

@testable import PrincipleCore

/// Every body here is invented `[FIXTURE]` text. The real corpus is copyrighted
/// and gitignored, so no test may carry a line of it.
@Suite("voice exemplars")
struct VoiceExemplarsTests {
    /// 45 invented words — over `minimumWords`, under `wordLimit`.
    private static func longBody(_ tag: String) -> String {
        "[FIXTURE] \(tag) " + (1...44).map { "từ\($0)" }.joined(separator: " ")
    }

    private func record(
        id: String,
        num: String,
        part: String = "Nguyên tắc sống",
        body: String
    ) -> PrincipleRecord {
        PrincipleRecord(
            id: id, part: part, chapter: "Chương thử", num: num,
            title: "[FIXTURE] Tiêu đề \(num)", body: body, hasBody: !body.isEmpty
        )
    }

    private func corpus(_ records: [PrincipleRecord]) -> CorpusStore { CorpusStore(records: records) }

    @Test("Lấy đúng các id đã chọn, theo đúng thứ tự đã khai trong code")
    func picksTheChosenIDsInOrder() {
        let store = corpus(
            VoiceExemplars.ids.reversed().map {
                record(id: $0, num: String($0.split(separator: ":")[1]), body: Self.longBody($0))
            }
        )

        let voice = VoiceExemplars(corpus: store)

        #expect(voice.passages.map(\.num) == VoiceExemplars.ids.map { String($0.split(separator: ":")[1]) })
    }

    @Test("Thân bài dài bị cắt trên ranh giới từ và đánh dấu bằng dấu ba chấm")
    func cutsALongBodyOnAWordBoundary() throws {
        let body = "[FIXTURE] " + (1...400).map { "từ\($0)" }.joined(separator: " ")
        let voice = VoiceExemplars(corpus: corpus([record(id: "life:1.6", num: "1.6", body: body)]))

        let passage = try #require(voice.passages.first)
        #expect(passage.text.split(whereSeparator: \.isWhitespace).count == VoiceExemplars.wordLimit)
        #expect(passage.text.hasSuffix("…"))
        #expect(passage.text.hasPrefix("[FIXTURE] từ1 từ2"))
    }

    @Test("Thân bài vừa đủ ngắn được lấy trọn, không có dấu ba chấm")
    func keepsAShortEnoughBodyWhole() throws {
        let body = Self.longBody("nguyên vẹn")
        let voice = VoiceExemplars(corpus: corpus([record(id: "life:1.6", num: "1.6", body: body)]))

        let passage = try #require(voice.passages.first)
        #expect(passage.text == body)
        #expect(!passage.text.hasSuffix("…"))
    }

    /// A heading-only record *is* the principle (AE3) — there is no prose in it
    /// to show a cadence with, and inventing one is the one thing forbidden.
    @Test("Bỏ qua id lạ, bản chỉ có tiêu đề, và thân bài quá ngắn")
    func skipsWhatCannotTeachACadence() {
        let store = corpus([
            record(id: "life:1.6", num: "1.6", body: ""),
            record(id: "life:1.10g", num: "1.10g", body: "[FIXTURE] Quá ngắn để làm mẫu nhịp văn."),
            record(id: "life:2.3b", num: "2.3b", body: Self.longBody("giữ lại")),
        ])

        let voice = VoiceExemplars(corpus: store)

        #expect(voice.passages.map(\.num) == ["2.3b"])
    }

    @Test("Không có corpus thì không có đoạn mẫu, và cũng không có khối prompt")
    func anEmptyCorpusYieldsNothing() {
        let voice = VoiceExemplars(corpus: CorpusStore(records: []))

        #expect(voice == .empty)
        #expect(voice.promptSection.isEmpty)
    }

    @Test("Tổng số từ của mọi đoạn không vượt trần")
    func staysUnderTheTotalWordCap() {
        let body = "[FIXTURE] " + (1...400).map { "từ\($0)" }.joined(separator: " ")
        let store = corpus(
            VoiceExemplars.ids.map { record(id: $0, num: String($0.split(separator: ":")[1]), body: body) }
        )

        let voice = VoiceExemplars(corpus: store)

        let words = voice.passages.reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
        #expect(words <= VoiceExemplars.totalWordCap)
        #expect(!voice.passages.isEmpty)
    }

    @Test("Khối prompt: tiêu đề, đoạn trong ngoặc kép, số hiệu kèm phần sách")
    func buildsTheQuotedBlock() {
        let store = corpus([
            record(id: "life:1.6", num: "1.6", body: Self.longBody("một")),
            record(id: "work:3.3c", num: "3.3c", part: "Nguyên tắc làm việc", body: Self.longBody("hai")),
        ])

        let section = VoiceExemplars(corpus: store).promptSection

        #expect(section.hasPrefix(VoiceExemplars.header))
        #expect(section.contains("\"[FIXTURE] một"))
        #expect(section.contains("(nguyên tắc 1.6, phần Nguyên tắc sống)"))
        #expect(section.contains("(nguyên tắc 3.3c, phần Nguyên tắc làm việc)"))
    }

    /// The static prompt points the engine at this heading by name, and
    /// `Tests/E2E/e2e-smoke.sh` reads the literal straight out of the source.
    @Test("Tiêu đề khối khớp với chỗ system prompt trỏ tới và sống sót qua awk")
    func theHeaderMatchesWhatThePromptAnnounces() {
        #expect(VoiceExemplars.header.hasPrefix(VoiceExemplars.headerTitle))
        #expect(ConsultPrompt.systemPrompt.contains(VoiceExemplars.headerTitle))
        #expect(!VoiceExemplars.header.contains("\\("))
    }

    @Test("Đọc thẳng từ corpus của một repo trên đĩa")
    func readsFromARepoOnDisk() throws {
        let repo = try TempRepo(prefix: "voice")
        let url = CorpusStore.corpusURL(inRepo: repo.root)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let line = try String(
            decoding: JSONEncoder().encode(record(id: "life:1.6", num: "1.6", body: Self.longBody("đĩa"))),
            as: UTF8.self
        )
        try (line + "\n").write(to: url, atomically: true, encoding: .utf8)

        let voice = VoiceExemplars(repoURL: repo.root)

        #expect(voice.passages.map(\.num) == ["1.6"])
        #expect(VoiceExemplars(repoURL: repo.root.appendingPathComponent("khong-co")) == .empty)
    }
}
