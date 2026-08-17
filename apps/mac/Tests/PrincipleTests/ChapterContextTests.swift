import Foundation
import Testing

@testable import PrincipleCore

private func fixtureStore() throws -> CorpusStore {
    CorpusStore(fileURL: try #require(Bundle.module.url(forResource: "Fixtures/corpus-sample", withExtension: "jsonl")))
}

private func sibling(id: String, num: String, chapter: String) -> PrincipleRecord {
    PrincipleRecord(
        id: id,
        part: "Nguyên tắc sống",
        chapter: chapter,
        num: num,
        title: "[FIXTURE] Nguyên tắc lân cận \(num)",
        body: "",
        hasBody: false
    )
}

@Suite("ChapterContext")
struct ChapterContextTests {
    // MARK: - 3. Neighbours of a principle (R8)

    @Test("Ngữ cảnh chương của life:5.6 → các nguyên tắc cùng chương, theo thứ tự corpus")
    func listsSameChapterPrinciplesInCorpusOrder() throws {
        let chapter = "Chương 5 — Quyết định giả lập"
        let current = try #require(try fixtureStore().principle(id: "life:5.6"))
        #expect(current.chapter == chapter)

        // Corpus mẫu chỉ có một mục mỗi chương, nên dựng thêm hai mục cùng chương
        // xen kẽ để kiểm tra đúng thứ tự corpus (không phải thứ tự số).
        let corpus = CorpusStore(records: [
            sibling(id: "life:5.5", num: "5.5", chapter: chapter),
            sibling(id: "life:1.9", num: "1.9", chapter: "Chương 1 — Khởi đầu giả lập"),
            current,
            sibling(id: "life:overview:1", num: "•", chapter: ""),
            sibling(id: "life:5.7", num: "5.7", chapter: chapter),
        ])

        let context = ChapterContext(corpus: corpus, record: current)
        #expect(context.hasContext)
        #expect(context.chapter == chapter)
        #expect(context.principles.map(\.id) == ["life:5.5", "life:5.6", "life:5.7"])
        #expect(context.isCurrent(current))
        #expect(!context.isCurrent(context.principles[0]))
        #expect(context.id == current.id)
    }

    @Test("Lọc theo trường chapter, không theo tiền tố num")
    func matchesOnTheChapterFieldNotTheNumberPrefix() throws {
        let store = try fixtureStore()
        let current = try #require(store.principle(id: "life:2.1"))
        let context = ChapterContext(corpus: store, record: current)

        // work:2.1 cùng `num` nhưng khác chương → không được lọt vào.
        #expect(context.principles.map(\.id) == ["life:2.1"])
        #expect(context.principles.allSatisfy { $0.chapter == current.chapter })
    }

    // MARK: - 4. Records outside any chapter

    @Test("Record không thuộc chương nào → báo không có ngữ cảnh, không crash")
    func aChapterlessRecordReportsNoContext() throws {
        let store = try fixtureStore()
        let current = try #require(store.principle(id: "life:overview:0"))
        #expect(current.chapter.isEmpty)

        let context = ChapterContext(corpus: store, record: current)
        #expect(!context.hasContext)
        #expect(context.principles.isEmpty)
        #expect(context.chapter.isEmpty)
        #expect(!ChapterContext.noChapterMessage.isEmpty)
    }

    @Test("Corpus rỗng → ngữ cảnh rỗng, không crash")
    func anEmptyCorpusYieldsNoContext() throws {
        let current = try #require(try fixtureStore().principle(id: "life:5.6"))
        let context = ChapterContext(corpus: CorpusStore(records: []), record: current)
        #expect(!context.hasContext)
    }
}
