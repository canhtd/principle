import Foundation
import Testing

@testable import PrincipleCore

@Suite("TrailerParser")
struct TrailerParserTests {
    // MARK: - 3. A valid trailer at the end of an answer

    @Test("Trailer hợp lệ cuối câu trả lời → text sạch, đúng id, giữ thứ tự")
    func stripsTheTrailerAndKeepsTheCitedOrder() {
        let answer = """
            Chẩn đoán: anh đang lẫn giữa mong muốn và thực tế.

            Hướng đi: viết ra kết quả anh muốn trước, rồi mới bàn cách.
            PRINCIPLES_JSON: {"ids":["life:5.6","life:1.8"]}
            """

        let parsed = TrailerParser.parse(answer)
        #expect(parsed.principleIDs == ["life:5.6", "life:1.8"])
        #expect(!parsed.text.contains(TrailerParser.marker))
        #expect(parsed.text.hasPrefix("Chẩn đoán:"))
        #expect(parsed.text.hasSuffix("rồi mới bàn cách."))
    }

    @Test("Trailer còn dòng trống phía sau vẫn được nhận ra")
    func toleratesTrailingBlankLines() {
        let parsed = TrailerParser.parse(
            "Câu trả lời.\n\nPRINCIPLES_JSON: {\"ids\":[\"work:2.1\"]}\n\n  \n"
        )
        #expect(parsed.principleIDs == ["work:2.1"])
        #expect(parsed.text == "Câu trả lời.")
    }

    @Test("Id trùng trong trailer → gộp lại, vẫn giữ thứ tự trích dẫn")
    func deduplicatesIDsPreservingOrder() {
        let parsed = TrailerParser.parse(
            "Nội dung.\nPRINCIPLES_JSON: {\"ids\":[\"life:5.6\",\"life:5.6\",\" \",\"life:1.8\"]}"
        )
        #expect(parsed.principleIDs == ["life:5.6", "life:1.8"])
    }

    @Test("Trailer rỗng hợp lệ → không thẻ, nhưng dòng máy vẫn bị giấu")
    func hidesAValidButEmptyTrailer() {
        let parsed = TrailerParser.parse("Không nguyên tắc nào khớp.\nPRINCIPLES_JSON: {\"ids\":[]}")
        #expect(parsed.principleIDs.isEmpty)
        #expect(parsed.text == "Không nguyên tắc nào khớp.")
    }

    // MARK: - 4. AE2 — no trailer, or one the app cannot trust

    @Test("Không có trailer → không thẻ, text nguyên vẹn")
    func noTrailerLeavesTheTextAlone() {
        let answer = "Ray chưa trích nguyên tắc nào ở lượt này.\nAnh kể thêm bối cảnh đi."
        let parsed = TrailerParser.parse(answer)
        #expect(parsed.principleIDs.isEmpty)
        #expect(parsed.text == answer)
    }

    @Test("Trailer JSON hỏng → không thẻ, text nguyên vẹn, app không tự chế")
    func brokenTrailerJSONProducesNoCards() {
        for broken in [
            "PRINCIPLES_JSON: {\"ids\":[\"life:5.6\"",
            "PRINCIPLES_JSON: khong-phai-json",
            "PRINCIPLES_JSON:",
            "PRINCIPLES_JSON: {\"principles\":[\"life:5.6\"]}",
            "PRINCIPLES_JSON: {\"ids\":\"life:5.6\"}",
        ] {
            let answer = "Câu trả lời.\n\(broken)"
            let parsed = TrailerParser.parse(answer)
            #expect(parsed.principleIDs.isEmpty, "\(broken) phải bị bỏ qua")
            #expect(parsed.text == answer, "\(broken) không được sửa text")
        }
    }

    @Test("Marker nằm giữa bài, không phải dòng cuối → không thẻ, text nguyên vẹn")
    func markerInTheMiddleIsNotATrailer() {
        let answer = "PRINCIPLES_JSON: {\"ids\":[\"life:5.6\"]}\nCòn một đoạn nữa ở sau."
        let parsed = TrailerParser.parse(answer)
        #expect(parsed.principleIDs.isEmpty)
        #expect(parsed.text == answer)
    }

    @Test("Text rỗng → không thẻ, không crash")
    func emptyAnswerIsHandled() {
        let parsed = TrailerParser.parse("")
        #expect(parsed.text.isEmpty)
        #expect(parsed.principleIDs.isEmpty)
    }

    // MARK: - While the answer is still streaming

    @Test("Trailer đang stream dở không lộ ra màn hình")
    func hidesAPartialTrailerWhileStreaming() {
        #expect(TrailerParser.visibleText(streaming: "Câu trả lời.\nPRINCIPLES_JSON: {\"ids\":[\"life")
            == "Câu trả lời.")
        #expect(TrailerParser.visibleText(streaming: "Câu trả lời.\nPRINCIPLES_JSON:") == "Câu trả lời.")
    }

    @Test("Text bình thường khi stream không bị đụng tới")
    func leavesStreamingProseAlone() {
        let partial = "Chẩn đoán: anh đang\nPhân vân giữa hai hướng"
        #expect(TrailerParser.visibleText(streaming: partial) == partial)
        #expect(TrailerParser.visibleText(streaming: "") == "")
    }
}
