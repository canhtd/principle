import Foundation
import Testing

@testable import PrincipleCore

/// The `case` object rides the same trailer line as the cards, so the app can
/// write `memory/cases/` without the engine spending a `Write` on it.
@Suite("TrailerParser — trường case")
struct CaseSummaryTrailerTests {
    private let full = """
        Hãy chốt hướng trong tuần này.
        PRINCIPLES_JSON: {"diagnosis":{"kind":"Ca ưu tiên","why":"Mục tiêu chưa xếp hạng."},"principles":[{"id":"life:5.6","apply":"Bạn đang cân cảm giác, chưa cân giá trị kỳ vọng."}],"case":{"slug":"tri-hoan-viec-nho","problem":"Em cứ làm việc nhỏ trước.","real_problem":"Mục tiêu quý chưa được xếp hạng.","direction":"Chốt ba mục tiêu quý, rồi log năm ngày xem việc nào lệch.","price":"Phải bỏ vài việc đang dở.","flip":"Log cho thấy việc nhỏ đúng là việc chặn đường.","follow_up":"2026-08-22","goal":"Ra mắt bản 1.0","continues":"2026-08-15-bo-thuoc-la-con-them.md"}}
        """

    @Test("Trailer có `case` → app đọc đủ chín trường")
    func parsesTheCaseObject() throws {
        let parsed = TrailerParser.parse(full)
        let summary = try #require(parsed.caseSummary)

        #expect(parsed.text == "Hãy chốt hướng trong tuần này.")
        #expect(summary.slug == "tri-hoan-viec-nho")
        #expect(summary.problem == "Em cứ làm việc nhỏ trước.")
        #expect(summary.realProblem == "Mục tiêu quý chưa được xếp hạng.")
        #expect(summary.direction == "Chốt ba mục tiêu quý, rồi log năm ngày xem việc nào lệch.")
        #expect(summary.price == "Phải bỏ vài việc đang dở.")
        #expect(summary.flip == "Log cho thấy việc nhỏ đúng là việc chặn đường.")
        #expect(summary.followUp == "2026-08-22")
        #expect(summary.goal == "Ra mắt bản 1.0")
        #expect(summary.continues == "2026-08-15-bo-thuoc-la-con-them.md")
        // The cards are unaffected by the new field.
        #expect(parsed.principleIDs == ["life:5.6"])
    }

    /// Sessions filed before the app owned the case file, and any turn where the
    /// engine only cited: no case, and nothing invented in its place (AE2).
    @Test("Trailer không có `case` → không ghi ca, thẻ vẫn dựng bình thường")
    func aTrailerWithoutACaseFilesNothing() {
        let parsed = TrailerParser.parse(
            "Câu trả lời.\nPRINCIPLES_JSON: {\"diagnosis\":{\"kind\":\"Ca A\",\"why\":\"Vì thế.\"},\"principles\":[{\"id\":\"life:5.6\",\"apply\":\"Ở đây.\"}]}"
        )

        #expect(parsed.caseSummary == nil)
        #expect(parsed.principleIDs == ["life:5.6"])
        #expect(parsed.diagnosis?.kind == "Ca A")
    }

    @Test("Trailer cũ chỉ có ids vẫn đọc được, chỉ là không có ca")
    func theLegacyTrailerStillParses() {
        let parsed = TrailerParser.parse("Câu trả lời.\nPRINCIPLES_JSON: {\"ids\":[\"work:2.1\"]}")

        #expect(parsed.principleIDs == ["work:2.1"])
        #expect(parsed.caseSummary == nil)
    }

    /// The trailer's first job is the citation. A `case` the app cannot read
    /// must cost the case file and nothing else — the answer is already written.
    @Test("`case` hỏng chỉ mất file ca, không mất thẻ và không lộ dòng máy")
    func aBrokenCaseCostsOnlyTheCaseFile() {
        let parsed = TrailerParser.parse(
            "Câu trả lời.\nPRINCIPLES_JSON: {\"principles\":[{\"id\":\"life:5.6\",\"apply\":\"Ở đây.\"}],\"case\":\"khong-phai-object\"}"
        )

        #expect(parsed.text == "Câu trả lời.")
        #expect(parsed.principleIDs == ["life:5.6"])
        #expect(parsed.caseSummary == nil)
    }

    @Test("`case` thiếu trường → điền được gì ghi nấy, không bịa phần còn lại")
    func aPartialCaseIsStillACase() throws {
        let parsed = TrailerParser.parse(
            "Câu trả lời.\nPRINCIPLES_JSON: {\"case\":{\"slug\":\"ca-ngan\",\"direction\":\"Làm việc A trước.\"}}"
        )
        let summary = try #require(parsed.caseSummary)

        #expect(summary.slug == "ca-ngan")
        #expect(summary.direction == "Làm việc A trước.")
        #expect(summary.problem.isEmpty)
        #expect(summary.followUp.isEmpty)
    }

    /// The prompt offers `—` for "nothing here", so the file must not end up
    /// with a dash where a sentence belongs.
    @Test("Dấu — trong `case` đọc là không có, không phải nội dung")
    func placeholdersReadAsNothing() throws {
        let parsed = TrailerParser.parse(
            "Câu trả lời.\nPRINCIPLES_JSON: {\"case\":{\"slug\":\"ca\",\"direction\":\"Làm A.\",\"goal\":\"—\",\"continues\":\"—\",\"real_problem\":\"-\"}}"
        )
        let summary = try #require(parsed.caseSummary)

        #expect(summary.goal.isEmpty)
        #expect(summary.continues.isEmpty)
        #expect(summary.realProblem.isEmpty)
    }

    @Test("`case` rỗng hoàn toàn → không có ca để ghi")
    func anEmptyCaseIsNoCase() {
        let parsed = TrailerParser.parse(
            "Câu trả lời.\nPRINCIPLES_JSON: {\"case\":{\"slug\":\"\",\"direction\":\"  \"}}"
        )

        #expect(parsed.caseSummary == nil)
    }

    /// The slug becomes a filename, so it has to survive being reduced to ascii
    /// even when the engine ignores the rule and answers in Vietnamese.
    @Test("Slug có dấu vẫn ra tên file đọc được, không rơi mất chữ")
    func theSlugSurvivesVietnamese() {
        #expect(CaseSummary(slug: "Bỏ thuốc lá — cơn thèm").fileSlug == "bo-thuoc-la-con-them")
        #expect(CaseSummary(slug: "", problem: "Chọn giữa hai lời mời làm việc.").fileSlug == "chon-giua-hai-loi-moi-lam")
        #expect(CaseSummary(slug: "!!!", direction: "").fileSlug == "ca")
    }
}
