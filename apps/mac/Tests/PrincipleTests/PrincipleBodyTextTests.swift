import Foundation
import Testing

@testable import PrincipleCore

/// Fixtures are invented, never the real translation: the real corpus is
/// gitignored for copyright while this file is committed.
@Suite("PrincipleBodyText.subPointsOnOwnLines")
struct PrincipleBodyTextTests {
    @Test("Các ý a. b. c. dính liền nhau được tách xuống dòng")
    func splitsRunOnSubPoints() {
        let body = "a. Ý thứ nhất.b. Ý thứ hai.c. Ý thứ ba."
        #expect(
            PrincipleBodyText.subPointsOnOwnLines(body) == "a. Ý thứ nhất.\nb. Ý thứ hai.\nc. Ý thứ ba."
        )
    }

    @Test("Khoảng trắng trước ý đầu tiên không sinh ra dòng trống")
    func leadingSpaceDoesNotMakeABlankLine() {
        let body = " a. Ý thứ nhất.b. Ý thứ hai."
        #expect(PrincipleBodyText.subPointsOnOwnLines(body) == "a. Ý thứ nhất.\nb. Ý thứ hai.")
    }

    @Test("Có câu mở đầu thì câu đó ở lại dòng của nó")
    func keepsTheLeadIn() {
        let body = "Hãy làm ba việc. a. Việc thứ nhất.b. Việc thứ hai."
        #expect(
            PrincipleBodyText.subPointsOnOwnLines(body)
                == "Hãy làm ba việc.\na. Việc thứ nhất.\nb. Việc thứ hai."
        )
    }

    @Test("Ý đã nằm sẵn trên dòng riêng thì giữ nguyên, không thêm dòng trống")
    func leavesAlreadySplitTextAlone() {
        let body = "a. Ý thứ nhất.\nb. Ý thứ hai."
        #expect(PrincipleBodyText.subPointsOnOwnLines(body) == body)
    }

    @Test("Một chữ cái lẻ giữa văn xuôi không phải danh sách — không cắt")
    func aSingleLetterIsNotAList() {
        let body = "Phương án a. là phương án duy nhất anh chưa thử."
        #expect(PrincipleBodyText.subPointsOnOwnLines(body) == body)
    }

    @Test("Chữ cái không nối tiếp bảng chữ cái thì bỏ qua")
    func lettersMustContinueTheAlphabet() {
        // `c.` không đi sau `a.` — chỉ `a.` được nhận, dưới ngưỡng hai ý.
        let body = "a. Ý thứ nhất.c. Ý lạc loài."
        #expect(PrincipleBodyText.subPointsOnOwnLines(body) == body)
    }

    @Test("Chữ cái nằm trong từ không bị nhầm là ký hiệu ý")
    func aLetterInsideAWordIsNotAMarker() {
        // "dữ liệu a." mở một ý; "beta." và "delta." thì không.
        let body = "Xem beta. a. Ý thứ nhất.b. Ý thứ hai."
        #expect(
            PrincipleBodyText.subPointsOnOwnLines(body) == "Xem beta.\na. Ý thứ nhất.\nb. Ý thứ hai."
        )
    }

    @Test("Không có ký hiệu ý nào thì trả lại đúng chuỗi cũ")
    func plainProseIsUntouched() {
        let body = "Đau đớn cộng suy ngẫm bằng tiến bộ."
        #expect(PrincipleBodyText.subPointsOnOwnLines(body) == body)
        #expect(PrincipleBodyText.subPointsOnOwnLines("") == "")
    }

    @Test("detailBody đi qua bộ tách; bản ghi chỉ có tiêu đề vẫn không có thân bài (AE3)")
    func recordDetailBody() {
        let listed = PrincipleRecord(
            id: "life:5.6",
            part: "Nguyên tắc sống",
            chapter: "",
            num: "5.6",
            title: "[FIXTURE] Tiêu đề",
            body: "a. Ý thứ nhất.b. Ý thứ hai.",
            hasBody: true
        )
        #expect(listed.detailBody == "a. Ý thứ nhất.\nb. Ý thứ hai.")

        let headingOnly = PrincipleRecord(
            id: "life:1.6",
            part: "Nguyên tắc sống",
            chapter: "",
            num: "1.6",
            title: "[FIXTURE] Tiêu đề",
            body: "",
            hasBody: false
        )
        #expect(headingOnly.detailBody == nil)
    }
}
