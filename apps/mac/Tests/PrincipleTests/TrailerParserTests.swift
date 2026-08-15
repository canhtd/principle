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

    /// The chunk boundary that leaked the raw marker: the answer arrives with
    /// the trailer's own newline already in it, so the last segment is empty
    /// and the marker is one line further up.
    @Test("Trailer đứng trước dấu xuống dòng cuối vẫn bị giấu")
    func hidesATrailerFollowedByANewline() {
        #expect(TrailerParser.visibleText(streaming: "Câu trả lời.\nPRINCIPLES_JSON:\n") == "Câu trả lời.")
        #expect(
            TrailerParser.visibleText(streaming: "Câu trả lời.\nPRINCIPLES_JSON: {\"ids\":[\n\n")
                == "Câu trả lời.")
        #expect(
            TrailerParser.visibleText(streaming: "Câu trả lời.\nPRINCIPLES_JSON: {\"ids\":[  \n")
                == "Câu trả lời.")
    }

    @Test("Text bình thường khi stream không bị đụng tới")
    func leavesStreamingProseAlone() {
        let partial = "Chẩn đoán: anh đang\nPhân vân giữa hai hướng"
        #expect(TrailerParser.visibleText(streaming: partial) == partial)
        #expect(TrailerParser.visibleText(streaming: "") == "")
    }
}

@Suite("TrailerParser — trailer giàu (chẩn đoán + bắc cầu)")
struct RichTrailerParserTests {
    private let answer = """
        Đây là ca quyết định dưới sức ép thời gian.
        PRINCIPLES_JSON: {"diagnosis":{"kind":"Ca cửa một chiều","why":"Nhận rồi thì một năm sau mới rút ra được."},"principles":[{"id":"life:5.6","apply":"Bạn đang cân cảm giác chắc chắn, chưa cân giá trị kỳ vọng."},{"id":"work:2.1","apply":"Bất đồng trong đội đang bị để lộ ra muộn."}]}
        """

    @Test("Trailer giàu → chẩn đoán, id, và câu bắc cầu đều về đủ")
    func parsesDiagnosisAndBridges() throws {
        let parsed = TrailerParser.parse(answer)

        #expect(parsed.text == "Đây là ca quyết định dưới sức ép thời gian.")
        #expect(parsed.diagnosis?.kind == "Ca cửa một chiều")
        #expect(parsed.diagnosis?.why == "Nhận rồi thì một năm sau mới rút ra được.")
        #expect(parsed.principles.map(\.id) == ["life:5.6", "work:2.1"])
        #expect(parsed.principles.first?.apply == "Bạn đang cân cảm giác chắc chắn, chưa cân giá trị kỳ vọng.")
        #expect(parsed.principles.last?.displayApply == "Bất đồng trong đội đang bị để lộ ra muộn.")
        // The convenience the rest of the app still looks things up by.
        #expect(parsed.principleIDs == ["life:5.6", "work:2.1"])
    }

    @Test("Id trùng trong trailer giàu → giữ lần trích đầu cùng câu bắc cầu của nó")
    func deduplicatesKeepingTheFirstBridge() {
        let parsed = TrailerParser.parse(
            """
            Nội dung.
            PRINCIPLES_JSON: {"principles":[{"id":"life:5.6","apply":"Bắc cầu đầu."},{"id":" ","apply":"x"},{"id":"life:5.6","apply":"Bắc cầu sau."}]}
            """
        )
        #expect(parsed.principles.count == 1)
        #expect(parsed.principles.first?.apply == "Bắc cầu đầu.")
    }

    @Test("Chẩn đoán thiếu một nửa vẫn dùng được; thiếu cả hai thì coi như không có")
    func toleratesAHalfDiagnosis() {
        let half = TrailerParser.parse("Nội dung.\nPRINCIPLES_JSON: {\"diagnosis\":{\"kind\":\"Ca lặp lại\"}}")
        #expect(half.diagnosis == Diagnosis(kind: "Ca lặp lại", why: ""))
        #expect(half.principles.isEmpty)
        #expect(half.text == "Nội dung.")

        let blank = TrailerParser.parse("Nội dung.\nPRINCIPLES_JSON: {\"diagnosis\":{\"kind\":\" \",\"why\":\"\"}}")
        #expect(blank.diagnosis == nil)
    }

    @Test("Không tra được nguyên tắc nào: giữ chẩn đoán, không thẻ, dòng máy vẫn bị giấu")
    func keepsTheDiagnosisWhenNothingWasCited() {
        let parsed = TrailerParser.parse(
            "Không nguyên tắc nào khớp.\nPRINCIPLES_JSON: {\"diagnosis\":{\"kind\":\"Ca ngoài sách\",\"why\":\"Không grep ra gì.\"},\"principles\":[]}"
        )
        #expect(parsed.diagnosis?.kind == "Ca ngoài sách")
        #expect(parsed.principles.isEmpty)
        #expect(parsed.text == "Không nguyên tắc nào khớp.")
    }

    @Test("Trailer cũ {\"ids\":[…]} vẫn đọc được, chỉ là không có câu bắc cầu")
    func stillReadsTheLegacyShape() {
        let parsed = TrailerParser.parse("Nội dung.\nPRINCIPLES_JSON: {\"ids\":[\"life:5.6\"]}")
        #expect(parsed.principles == [PrincipleRef(id: "life:5.6")])
        #expect(parsed.principles.first?.apply.isEmpty == true)
        #expect(parsed.principles.first?.displayApply == nil)
        #expect(parsed.diagnosis == nil)
    }

    @Test("Có cả hai dạng thì dạng giàu thắng")
    func theRichShapeWinsOverTheLegacyOne() {
        let parsed = TrailerParser.parse(
            "Nội dung.\nPRINCIPLES_JSON: {\"ids\":[\"life:1.8\"],\"principles\":[{\"id\":\"life:5.6\",\"apply\":\"Bắc cầu.\"}]}"
        )
        #expect(parsed.principleIDs == ["life:5.6"])
    }

    @Test("Trailer đúng cú pháp nhưng rỗng → không thẻ, và không để lộ dòng máy")
    func hidesAWellFormedButEmptyTrailer() {
        let parsed = TrailerParser.parse("Nội dung.\nPRINCIPLES_JSON: {}")
        #expect(parsed.principles.isEmpty)
        #expect(parsed.diagnosis == nil)
        #expect(parsed.text == "Nội dung.")
    }

    @Test("Trailer giàu đang stream dở không lộ ra màn hình")
    func hidesAPartialRichTrailerWhileStreaming() {
        let partial = "Nội dung.\nPRINCIPLES_JSON: {\"diagnosis\":{\"kind\":\"Ca cửa một"
        #expect(TrailerParser.visibleText(streaming: partial) == "Nội dung.")
    }
}
