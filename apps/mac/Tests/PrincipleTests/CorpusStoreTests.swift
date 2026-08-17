import Foundation
import Testing

@testable import PrincipleCore

/// The fixture is invented, never the real translation: the real corpus is
/// gitignored for copyright while this file is committed.
private func fixtureURL() throws -> URL {
    try #require(Bundle.module.url(forResource: "Fixtures/corpus-sample", withExtension: "jsonl"))
}

private func fixtureStore() throws -> CorpusStore {
    CorpusStore(fileURL: try fixtureURL())
}

@Suite("CorpusStore")
struct CorpusStoreTests {
    // MARK: - Loading

    @Test("Đọc corpus.jsonl và bỏ qua dòng hỏng thay vì gãy cả file")
    func loadsValidRecordsAndSkipsBrokenLines() throws {
        let store = try fixtureStore()
        // Six well-formed records; the truncated line and the record without an
        // id are dropped, the blank line is ignored.
        #expect(store.count == 6)
        #expect(!store.isEmpty)
        #expect(store.principle(id: "work:broken") == nil)
    }

    @Test("Không có corpus trên đĩa → store rỗng, không crash")
    func missingCorpusLoadsEmpty() throws {
        let repo = try TempRepo(prefix: "corpus")
        let store = CorpusStore(repoURL: repo.root)
        #expect(store.isEmpty)
        #expect(store.principle(id: "life:5.6") == nil)
        #expect(store.principles(ids: ["life:5.6"]).isEmpty)
    }

    @Test("File corpus rác → store rỗng, không crash")
    func unreadableCorpusLoadsEmpty() throws {
        let repo = try TempRepo(prefix: "corpus")
        let corpus = CorpusStore.corpusURL(inRepo: repo.root)
        try FileManager.default.createDirectory(
            at: corpus.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("khong-phai-json\n{{{\n".utf8).write(to: corpus)

        #expect(CorpusStore(repoURL: repo.root).isEmpty)
    }

    @Test("Đường dẫn corpus suy từ repo đúng vị trí KTD")
    func resolvesCorpusPathInsideTheRepo() throws {
        let repo = try TempRepo(prefix: "corpus")
        let corpus = CorpusStore.corpusURL(inRepo: repo.root)
        #expect(corpus.path.hasSuffix(".claude/skills/ask-ray/references/corpus.jsonl"))

        try FileManager.default.createDirectory(
            at: corpus.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: try fixtureURL(), to: corpus)
        #expect(CorpusStore(repoURL: repo.root).count == 6)
    }

    // MARK: - 1. Lookup by id

    @Test("Tra id 'life:5.6' ra đúng title và body nguyên văn")
    func looksUpAKnownID() throws {
        let principle = try #require(try fixtureStore().principle(id: "life:5.6"))
        #expect(principle.num == "5.6")
        #expect(principle.part == "Nguyên tắc sống")
        #expect(principle.chapter == "Chương 5 — Quyết định giả lập")
        #expect(principle.title == "[FIXTURE] Cân giá trị kỳ vọng thay vì cảm giác chắc chắn")
        #expect(principle.hasBody)
        #expect(principle.displayBody?.hasPrefix("[FIXTURE] Dòng dữ liệu bịa ra") == true)
    }

    @Test("Id không có trong corpus → nil, không crash")
    func unknownIDReturnsNil() throws {
        #expect(try fixtureStore().principle(id: "life:999.9") == nil)
    }

    @Test("Tra theo danh sách id giữ đúng thứ tự và bỏ id lạ, không bịa thẻ")
    func resolvesIDsInOrderAndDropsUnknownOnes() throws {
        let resolved = try fixtureStore().principles(ids: ["life:5.6", "life:999.9", "life:1.8"])
        #expect(resolved.map(\.id) == ["life:5.6", "life:1.8"])
    }

    // MARK: - 2. AE3 — title-only records

    @Test("has_body:false → thẻ chỉ có title, không body rỗng và không body bịa")
    func titleOnlyRecordExposesNoBody() throws {
        let principle = try #require(try fixtureStore().principle(id: "work:3.4"))
        #expect(!principle.hasBody)
        #expect(principle.body.isEmpty)
        #expect(principle.displayBody == nil)
        #expect(principle.title == "[FIXTURE] Giao việc theo năng lực đã chứng minh, không theo thiện chí")
    }

    @Test("has_body:true nhưng body rỗng → vẫn không hiện body")
    func emptyBodyIsNeverShown() {
        let principle = PrincipleRecord(
            id: "life:0.0",
            part: "Nguyên tắc sống",
            chapter: "Chương 0",
            num: "0.0",
            title: "[FIXTURE] Tiêu đề",
            body: "   \n ",
            hasBody: true
        )
        #expect(principle.displayBody == nil)
    }

    // MARK: - 5. Duplicate `num` across the two parts

    @Test("num '2.1' có ở cả hai phần → hai id khác nhau, hai bản ghi phân biệt")
    func duplicateNumResolvesToTwoDistinctRecords() throws {
        let store = try fixtureStore()
        let life = try #require(store.principle(id: "life:2.1"))
        let work = try #require(store.principle(id: "work:2.1"))

        #expect(life.num == work.num)
        #expect(life.id != work.id)
        #expect(life.part == "Nguyên tắc sống")
        #expect(work.part == "Nguyên tắc làm việc")
        #expect(life.chapter == "Chương 2 — Sự thật giả lập")
        #expect(work.chapter == "Chương 9 — Văn hoá giả lập")
        #expect(life.title != work.title)

        // Both cited at once: two separate cards, nothing collapsed or swapped.
        #expect(store.principles(ids: ["work:2.1", "life:2.1"]).map(\.id) == ["work:2.1", "life:2.1"])
        // Secondary index, manual lookup only — `num` is not a key.
        #expect(Set(store.principles(num: "2.1").map(\.id)) == ["life:2.1", "work:2.1"])
        #expect(store.principles(num: "5.6").map(\.id) == ["life:5.6"])
    }

    // MARK: - Caption

    @Test("Caption ghép num · phần · chương, bỏ chương rỗng")
    func captionOmitsAnEmptyChapter() throws {
        let store = try fixtureStore()
        let inChapter = try #require(store.principle(id: "life:5.6"))
        #expect(inChapter.caption == "5.6 · Nguyên tắc sống · Chương 5 — Quyết định giả lập")

        let noChapter = try #require(store.principle(id: "life:overview:0"))
        #expect(noChapter.chapter.isEmpty)
        #expect(noChapter.caption == "• · Nguyên tắc sống")
    }
}
