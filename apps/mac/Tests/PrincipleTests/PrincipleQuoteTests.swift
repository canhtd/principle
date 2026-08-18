import Foundation
import Testing

@testable import PrincipleCore

/// The fixture is invented, never the real translation: the real corpus is
/// gitignored for copyright while this file is committed.
private func fixtureStore() throws -> CorpusStore {
    CorpusStore(
        fileURL: try #require(Bundle.module.url(forResource: "Fixtures/corpus-sample", withExtension: "jsonl"))
    )
}

/// The ≤40-word quote a principle card shows under its title, per the artifact
/// spec. Verbatim or nothing (AE2/AE3).
@Suite("PrincipleRecord.quote")
struct PrincipleQuoteTests {
    // MARK: - Quote (artifact spec: ≤ 40 words, cut on a word boundary)

    @Test("Body dài hơn 40 từ → cắt đúng 40 từ trên ranh giới từ, đánh dấu bằng …")
    func quoteTruncatesOnAWordBoundary() throws {
        let words = (1...60).map { "từ\($0)" }
        let principle = PrincipleRecord(
            id: "life:0.1",
            part: "Nguyên tắc sống",
            chapter: "Chương 0",
            num: "0.1",
            title: "[FIXTURE] Tiêu đề",
            body: words.joined(separator: " "),
            hasBody: true
        )

        let quote = try #require(principle.quote)
        #expect(quote.hasSuffix("từ40…"))
        #expect(!quote.contains("từ41"))
        #expect(quote.split(separator: " ").count == PrincipleRecord.quoteWordLimit)
        // Verbatim up to the cut: the words are never rewritten (AE2).
        #expect(quote.hasPrefix("từ1 từ2 từ3"))
    }

    @Test("Body đúng 40 từ trở xuống → nguyên văn, không có dấu cắt")
    func quoteKeepsAShortBodyWhole() throws {
        let store = try fixtureStore()
        // The fixture body is exactly at the limit, which is the edge that
        // decides whether an ellipsis is honest.
        let atLimit = try #require(store.principle(id: "life:5.6"))
        let quote = try #require(atLimit.quote)
        #expect(quote.split(separator: " ").count == PrincipleRecord.quoteWordLimit)
        #expect(!quote.hasSuffix("…"))
        #expect(quote == atLimit.displayBody)

        let shorter = try #require(store.principle(id: "life:2.1"))
        #expect(shorter.quote == shorter.displayBody)
    }

    @Test("Xuống dòng trong body được gộp thành một dòng trích, chữ giữ nguyên")
    func quoteCollapsesWhitespaceOnly() {
        let principle = PrincipleRecord(
            id: "life:0.2",
            part: "Nguyên tắc sống",
            chapter: "Chương 0",
            num: "0.2",
            title: "[FIXTURE] Tiêu đề",
            body: "  Đau đớn\n\ncộng   suy ngẫm\nbằng tiến bộ.  ",
            hasBody: true
        )
        #expect(principle.quote == "Đau đớn cộng suy ngẫm bằng tiến bộ.")
    }

    @Test("has_body:false → không có trích dẫn, không bịa thân bài (AE3)")
    func titleOnlyRecordHasNoQuote() throws {
        let store = try fixtureStore()
        #expect(try #require(store.principle(id: "work:3.4")).quote == nil)
        #expect(store.quote(for: "work:3.4") == nil)
        // has_body:true but the body is blank is the same story.
        #expect(
            PrincipleRecord(
                id: "life:0.3",
                part: "Nguyên tắc sống",
                chapter: "",
                num: "0.3",
                title: "[FIXTURE] Tiêu đề",
                body: " \n ",
                hasBody: true
            ).quote == nil
        )
    }

    @Test("Tra trích dẫn theo id: id lạ → nil, không bịa thẻ")
    func quoteLookupByID() throws {
        let store = try fixtureStore()
        #expect(store.quote(for: "life:5.6") == store.principle(id: "life:5.6")?.quote)
        #expect(store.quote(for: "life:999.9") == nil)
    }

    /// The excerpt popover reads `displayBody`, never `quote`. `quote` ends in
    /// an `…` by construction, and the popover is the one place a principle is
    /// read in full — so the two must not drift back into each other.
    @Test("Body dài: quote cắt 40 từ và có …, displayBody giữ trọn vẹn, không có …")
    func displayBodyKeepsTheWholePassage() throws {
        let words = (1...120).map { "từ\($0)" }
        let body = words.joined(separator: " ")
        let principle = PrincipleRecord(
            id: "life:0.4",
            part: "Nguyên tắc sống",
            chapter: "Chương 0",
            num: "0.4",
            title: "[FIXTURE] Tiêu đề",
            body: body,
            hasBody: true
        )

        let full = try #require(principle.displayBody)
        #expect(full == body)
        #expect(!full.hasSuffix("…"))
        #expect(full.contains("từ120"))
        #expect(full.split(separator: " ").count == 120)

        // …while the card's own cut is unchanged, which is what makes the two
        // different things rather than two names for one.
        let card = try #require(principle.quote)
        #expect(card.hasSuffix("…"))
        #expect(card.split(separator: " ").count == PrincipleRecord.quoteWordLimit)
    }
}
