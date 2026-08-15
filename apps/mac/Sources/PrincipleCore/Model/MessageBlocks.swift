import Foundation

/// One rendered block of a message: the unit the chat draws as its own `Text`.
///
/// The engine answers in Markdown — paragraphs separated by blank lines, `###`
/// headings, `- ` / `1. ` lists, `**bold**` and `` `4.3e` `` inline. A single
/// `Text` over the whole answer would show all of that verbatim, so the answer
/// is cut into blocks here and the view styles each one.
public struct MessageBlock: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case paragraph
        case heading
        /// The bullet or number to draw in the gutter, already formatted.
        case listItem(marker: String)
    }

    /// Position in the message. Stable enough for `ForEach` while streaming:
    /// text only ever grows at the end, so earlier blocks keep their index.
    public let id: Int
    public let kind: Kind
    /// The block's own source, still carrying inline Markdown.
    public let text: String
    /// Whether a blank line stood before this block. Two list lines in a row
    /// are one list; the same two with a blank line between them are two, and
    /// the view spaces them apart accordingly.
    public let afterBlankLine: Bool

    public init(id: Int, kind: Kind, text: String, afterBlankLine: Bool = false) {
        self.id = id
        self.kind = kind
        self.text = text
        self.afterBlankLine = afterBlankLine
    }
}

/// Block-level Markdown, done by hand.
///
/// Foundation parses inline Markdown (`AttributedString(markdown:)`) but its
/// block support ignores what this app needs — paragraphs, headings and lists
/// as separate views with their own spacing. Only the block split lives here;
/// everything inside a block is handed back to Foundation by ``attributed(_:)``.
public enum MessageBlocks {
    /// Bullet markers accepted from the engine, all drawn as one bullet.
    private static let bulletPrefixes = ["- ", "* ", "+ "]

    /// One line of prose is one paragraph.
    ///
    /// Markdown would join two prose lines separated by a single newline into
    /// one paragraph, and an answer that forgets its blank lines then renders as
    /// a single wall of text — which is what a real answer did. The engine never
    /// hard-wraps its prose, so the newline it writes always means a break; the
    /// blank line is still recorded on the block, because two list lines in a row
    /// are one list and the view spaces them accordingly.
    public static func parse(_ text: String) -> [MessageBlock] {
        var blocks: [MessageBlock] = []
        var sawBlankLine = false

        func append(_ kind: MessageBlock.Kind, _ text: String) {
            blocks.append(
                MessageBlock(id: blocks.count, kind: kind, text: text, afterBlankLine: sawBlankLine)
            )
            sawBlankLine = false
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                sawBlankLine = true
            } else if let heading = heading(in: line) {
                append(.heading, heading)
            } else if let item = listItem(in: line) {
                append(.listItem(marker: item.marker), item.text)
            } else {
                append(.paragraph, line)
            }
        }
        return blocks
    }

    /// The text of a `#`…`######` heading, or `nil` when the line is not one.
    /// A bare `#` with nothing after it is prose, not a heading.
    private static func heading(in line: String) -> String? {
        let hashes = line.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count) else { return nil }
        let rest = line.dropFirst(hashes.count)
        guard rest.first == " " else { return nil }
        let title = rest.trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }

    /// The marker and body of a list line, or `nil` when the line is not one.
    private static func listItem(in line: String) -> (marker: String, text: String)? {
        for prefix in bulletPrefixes where line.hasPrefix(prefix) {
            let text = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : (marker: "•", text: text)
        }
        return orderedListItem(in: line)
    }

    /// `1. ` or `1) ` — the number is kept as written, so a list that starts at
    /// 3 still reads as 3.
    private static func orderedListItem(in line: String) -> (marker: String, text: String)? {
        let digits = line.prefix(while: \.isNumber)
        guard !digits.isEmpty, digits.count <= 3 else { return nil }
        let rest = line.dropFirst(digits.count)
        guard let separator = rest.first, separator == "." || separator == ")" else { return nil }
        let body = rest.dropFirst()
        guard body.first == " " else { return nil }
        let text = body.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : (marker: "\(digits).", text: text)
    }

    // MARK: - Inline

    /// A block's inline Markdown, resolved to an `AttributedString`.
    ///
    /// `inlineOnlyPreservingWhitespace` leaves block syntax alone — the split
    /// above already did that job — and keeps whatever whitespace a block does
    /// carry. Anything the parser refuses is shown as plain text rather than
    /// dropped: half an answer is worse than an unstyled one.
    ///
    /// `parse` is a seam for tests; callers use the default.
    public static func attributed(
        _ source: String,
        parse: (String) throws -> AttributedString = parseInlineMarkdown
    ) -> AttributedString {
        (try? parse(source)) ?? AttributedString(source)
    }

    public static func parseInlineMarkdown(_ source: String) throws -> AttributedString {
        try AttributedString(
            markdown: source,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
    }
}
