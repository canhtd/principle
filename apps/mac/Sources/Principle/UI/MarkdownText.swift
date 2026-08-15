import PrincipleCore
import SwiftUI

/// A message body, rendered from the Markdown the engine writes.
///
/// The blocks come from ``MessageBlocks/parse(_:)``; this view only decides how
/// each one looks. Parsing runs on every update rather than being cached: an
/// answer streams in character by character, and a cache keyed on the text
/// would be rebuilt every frame anyway while costing the block views their
/// identity.
struct MarkdownText: View {
    let text: String

    var body: some View {
        let blocks = MessageBlocks.parse(text)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                view(for: block)
                    .padding(.top, topPadding(for: block, after: index == 0 ? nil : blocks[index - 1]))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func view(for block: MessageBlock) -> some View {
        switch block.kind {
        case .paragraph:
            paragraph(block.text)
        case .heading:
            Text(styled(block.text))
                .font(Typography.title)
                .lineSpacing(Typography.titleLineSpacing)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .listItem(let marker):
            HStack(alignment: .firstTextBaseline, spacing: Spacing.listMarkerGap) {
                Text(marker)
                    .vietnameseBody()
                    .foregroundStyle(.secondary)
                paragraph(block.text)
            }
            .padding(.leading, Spacing.listIndent)
        }
    }

    private func paragraph(_ source: String) -> some View {
        Text(styled(source))
            .vietnameseBody()
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Blocks breathe, lines of one list stay together, headings get extra air
    /// above. A blank line in the source ends a list, so two lists written apart
    /// do not merge into one.
    private func topPadding(for block: MessageBlock, after previous: MessageBlock?) -> CGFloat {
        guard let previous else { return 0 }
        if case .listItem = block.kind, case .listItem = previous.kind, !block.afterBlankLine {
            return Spacing.listItem
        }
        if case .heading = block.kind { return Spacing.block + Spacing.headingTop }
        return Spacing.block
    }

    /// Inline Markdown as an `AttributedString`, with code runs put in the
    /// monospaced face — SwiftUI honours bold and italic on its own but leaves
    /// `` `code` `` in the body font.
    private func styled(_ source: String) -> AttributedString {
        var attributed = MessageBlocks.attributed(source)
        let codeRanges = attributed.runs
            .filter { $0.inlinePresentationIntent?.contains(.code) == true }
            .map(\.range)
        for range in codeRanges {
            attributed[range].font = Typography.mono
        }
        return attributed
    }
}

#Preview {
    MarkdownText(
        text: """
            ### [PREVIEW] Chẩn đoán

            Anh đang lẫn giữa **mong muốn** và thực tế. Nguyên tắc `4.3e` nói thẳng chuyện này.

            - Viết ra kết quả anh muốn trước
            - Rồi mới bàn cách

            1. Bước một
            2. Bước hai
            """
    )
    .padding()
    .frame(width: 520)
}
