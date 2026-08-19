import DesignSystem
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
    /// How the prose is set. One face today — the Ask Ray pane is the only
    /// place an answer is read — but it stays a parameter, because a second
    /// place to read one is a screen, not a rewrite of this view.
    var style: ProseStyle = .askRay

    /// The type a body of prose is set in.
    ///
    /// Everything but the colour is a ratio of ``size``: the block rhythm of a
    /// paragraph, a list and a heading only reads right relative to the type it
    /// separates, so one number moves the whole thing.
    struct ProseStyle {
        /// The size body copy is set at.
        let size: CGFloat
        /// The CSS line box, as a multiple of ``size``.
        let lineHeight: CGFloat
        let color: Color?
        /// Between two paragraphs. It has to beat ``lineSpacing`` by enough to
        /// read as a break rather than as one more line.
        let blockSpacing: CGFloat

        /// Eden's side-peek chat: 14 pt on a 1.65 line, in the pane's warm ink,
        /// with `.cc-md p`'s 0.9 rem between paragraphs.
        static let askRay = ProseStyle(
            size: RayChat.bodySize,
            lineHeight: RayChat.bodyLineHeight,
            color: RayChat.ink,
            blockSpacing: 14.4
        )

        var font: Font { EdenFont.ui(size) }
        /// SwiftUI takes extra spacing rather than a multiplier — and the
        /// leading matters more than the size for Vietnamese, whose marks sit
        /// above *and* below the line.
        var lineSpacing: CGFloat { size * (lineHeight - 1) }

        /// A `###` inside an answer: one step above the body it interrupts.
        /// The prototype sets no heading for the chat, so it is derived here
        /// rather than measured.
        var headingFont: Font { EdenFont.ui(size + 2, .semibold) }
        var headingLineSpacing: CGFloat { (size + 2) * 0.35 }
        /// Extra air above a heading that follows other content.
        var headingTop: CGFloat { size * 0.4 }
        /// Between two lines of the same list — tighter than a block, so the
        /// list reads as one thing rather than as loose paragraphs.
        var listItem: CGFloat { size * 0.3 }
        /// Gutter a list item is pushed in by.
        var listIndent: CGFloat { size * 0.5 }
        /// Between a bullet and its text.
        var listMarkerGap: CGFloat { size * 0.45 }
        /// Inline code — `4.3e`, a file path, a command. `DesignSystem` names
        /// no monospaced face, so this is the system one at the prose's size.
        var mono: Font { .system(size: size - 1, design: .monospaced) }
    }

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
                .font(style.headingFont)
                .lineSpacing(style.headingLineSpacing)
                .foregroundStyle(style.color ?? Color.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .listItem(let marker):
            HStack(alignment: .firstTextBaseline, spacing: style.listMarkerGap) {
                Text(marker)
                    .font(style.font)
                    .lineSpacing(style.lineSpacing)
                    .foregroundStyle(.secondary)
                paragraph(block.text)
            }
            .padding(.leading, style.listIndent)
        }
    }

    private func paragraph(_ source: String) -> some View {
        Text(styled(source))
            .font(style.font)
            .lineSpacing(style.lineSpacing)
            .foregroundStyle(style.color ?? Color.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Blocks breathe, lines of one list stay together, headings get extra air
    /// above. A blank line in the source ends a list, so two lists written apart
    /// do not merge into one.
    private func topPadding(for block: MessageBlock, after previous: MessageBlock?) -> CGFloat {
        guard let previous else { return 0 }
        if case .listItem = block.kind, case .listItem = previous.kind, !block.afterBlankLine {
            return style.listItem
        }
        if case .heading = block.kind { return style.blockSpacing + style.headingTop }
        return style.blockSpacing
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
            attributed[range].font = style.mono
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
    .frame(width: 380)
}
