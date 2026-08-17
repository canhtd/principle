import Foundation
import Testing

@testable import PrincipleCore

@Suite("MessageBlocks")
struct MessageBlocksTests {
    // MARK: - Paragraphs

    /// The model that forgets its blank lines used to render as one wall of
    /// text; a single newline between two prose lines now breaks the paragraph.
    @Test("Xuống dòng đơn cũng tách đoạn, không dồn thành một khối")
    func splitsParagraphsOnEveryNewline() {
        let blocks = MessageBlocks.parse(
            """
            Chẩn đoán: anh đang lẫn giữa mong muốn và thực tế.
            Chuyện này lặp lại nhiều lần.

            Hướng đi: viết ra kết quả anh muốn trước.
            """
        )

        #expect(blocks.count == 3)
        #expect(blocks.allSatisfy { $0.kind == .paragraph })
        #expect(blocks.allSatisfy { !$0.text.contains("\n") })
        #expect(blocks[1].text == "Chuyện này lặp lại nhiều lần.")
        #expect(blocks[2].text == "Hướng đi: viết ra kết quả anh muốn trước.")
        #expect(blocks.map(\.id) == [0, 1, 2])
    }

    /// The blank line still has to be visible on the block: it is what tells one
    /// list from two, and paragraphs written apart from paragraphs merely wrapped.
    @Test("Đoạn ngay sau dòng trống vẫn được đánh dấu afterBlankLine")
    func recordsTheBlankLineBetweenParagraphs() {
        let blocks = MessageBlocks.parse("Một.\nHai.\n\nBa.")
        #expect(blocks.map(\.afterBlankLine) == [false, false, true])
    }

    @Test("Nhiều dòng trống liên tiếp không sinh đoạn rỗng")
    func ignoresEmptyRuns() {
        let blocks = MessageBlocks.parse("\n\n  \nMột đoạn.\n\n\n\nĐoạn hai.\n  \n")
        #expect(blocks.map(\.text) == ["Một đoạn.", "Đoạn hai."])
    }

    @Test("Chuỗi rỗng hoặc chỉ khoảng trắng → không có block nào")
    func returnsNothingForBlankInput() {
        #expect(MessageBlocks.parse("").isEmpty)
        #expect(MessageBlocks.parse("   \n\n \t ").isEmpty)
    }

    // MARK: - Lists

    @Test("Dòng gạch đầu dòng thành list item, mọi ký hiệu đều ra một bullet")
    func detectsBulletItems() {
        let blocks = MessageBlocks.parse("- Một\n* Hai\n+ Ba")
        #expect(blocks.count == 3)
        #expect(blocks.map(\.kind) == Array(repeating: .listItem(marker: "•"), count: 3))
        #expect(blocks.map(\.text) == ["Một", "Hai", "Ba"])
    }

    @Test("List đánh số giữ đúng số đã viết")
    func keepsOrderedMarkers() {
        let blocks = MessageBlocks.parse("3. Bước ba\n4) Bước bốn")
        #expect(blocks.map(\.kind) == [.listItem(marker: "3."), .listItem(marker: "4.")])
        #expect(blocks.map(\.text) == ["Bước ba", "Bước bốn"])
    }

    @Test("Số thập phân và gạch ngang trơ trọi vẫn là văn xuôi")
    func doesNotMistakeProseForAList() {
        let blocks = MessageBlocks.parse("1.5 triệu đồng\n-\n2.Không có khoảng trắng")
        #expect(blocks.count == 3)
        #expect(blocks.allSatisfy { $0.kind == .paragraph })
        #expect(blocks.map(\.text) == ["1.5 triệu đồng", "-", "2.Không có khoảng trắng"])
    }

    @Test("Dòng trống giữa hai list được ghi lại, list liền mạch thì không")
    func marksTheBlankLineBetweenTwoLists() {
        let blocks = MessageBlocks.parse("- Một\n- Hai\n\n1. Bước một")
        #expect(blocks.map(\.afterBlankLine) == [false, false, true])
    }

    @Test("List ngay sau đoạn văn tách ra khỏi đoạn đó")
    func breaksAParagraphWhenAListStarts() {
        let blocks = MessageBlocks.parse("Ba việc cần làm:\n- Một\n- Hai")
        #expect(blocks.map(\.kind) == [.paragraph, .listItem(marker: "•"), .listItem(marker: "•")])
    }

    // MARK: - Headings

    @Test("### thành heading, dấu # bị bóc khỏi nội dung")
    func detectsHeadings() {
        let blocks = MessageBlocks.parse("### Chẩn đoán\nNội dung bên dưới.")
        #expect(blocks.count == 2)
        #expect(blocks[0].kind == .heading)
        #expect(blocks[0].text == "Chẩn đoán")
        #expect(blocks[1].kind == .paragraph)
    }

    @Test("# không có khoảng trắng, hoặc quá sáu dấu, không phải heading")
    func rejectsNonHeadings() {
        let blocks = MessageBlocks.parse("#hashtag\n\n####### bảy dấu\n\n#")
        #expect(blocks.allSatisfy { $0.kind == .paragraph })
        #expect(blocks.count == 3)
    }

    // MARK: - Inline

    @Test("Markdown inline được diễn giải: đậm mất dấu sao, code giữ ý nghĩa")
    func interpretsInlineMarkdown() {
        let attributed = MessageBlocks.attributed("**Chẩn đoán**: nguyên tắc `4.3e` nói thẳng")
        let plain = String(attributed.characters)

        #expect(plain == "Chẩn đoán: nguyên tắc 4.3e nói thẳng")
        let code = attributed.runs
            .filter { $0.inlinePresentationIntent?.contains(.code) == true }
            .map { String(attributed[$0.range].characters) }
        #expect(code == ["4.3e"])
    }

    @Test("Xuống dòng mềm trong một đoạn không bị nuốt")
    func preservesSoftLineBreaks() {
        let attributed = MessageBlocks.attributed("dòng một\ndòng hai")
        #expect(String(attributed.characters) == "dòng một\ndòng hai")
    }

    @Test("Parser inline ném lỗi → hiện nguyên văn, không mất chữ")
    func fallsBackToPlainTextWhenParsingFails() {
        struct ParseFailure: Error {}

        let source = "**đậm** và `code`"
        let attributed = MessageBlocks.attributed(source) { _ in throw ParseFailure() }

        #expect(String(attributed.characters) == source)
        #expect(attributed.runs.allSatisfy { $0.inlinePresentationIntent == nil })
    }
}
