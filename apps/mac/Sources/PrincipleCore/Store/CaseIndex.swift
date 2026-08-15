import Foundation

/// The one line every filed case adds to `memory/MEMORY.md`.
///
/// The same file holds the profile a terminal session hand-edits and the index
/// the skill reads before diagnosing anything, so a write here inserts one line
/// and leaves every other byte exactly as it was — the same rule
/// ``ProfileStore`` follows for its own section, for the same reason.
enum CaseIndex {
    /// The section the skill's index lives in, and the sub-heading the written
    /// cases are listed under. Vietnamese because the file belongs to the repo's
    /// memory protocol, not to the app.
    static let sectionHeading = "## Index ca"
    static let subHeading = "### Ca đã ghi"

    /// `ngày · slug · kiểu ca · hướng đã chốt · trạng thái`, the format the
    /// section documents about itself.
    static func line(
        day: String,
        slug: String,
        fileName: String,
        kind: String,
        direction: String,
        followUp: String
    ) -> String {
        let status = followUp.isEmpty ? "mở" : "mở (follow-up \(followUp))"
        let fields = [
            day,
            "[\(slug)](cases/\(fileName))",
            oneLine(kind),
            firstSentence(direction),
            status,
        ]
        return "- " + fields.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// `text` with `line` inserted at the end of the written-cases list.
    ///
    /// The sub-heading is created under `## Index ca` when it is missing, and
    /// both are created at the end of a file that has neither. Nothing else in
    /// the file is rewritten.
    static func appending(_ line: String, to text: String) -> String {
        guard let anchor = anchor(in: text) else { return appendingSection(line, to: text) }
        var updated = text
        updated.replaceSubrange(anchor.end..<anchor.end, with: anchor.separator + line)
        return updated
    }

    // MARK: - Where the line goes

    private struct Anchor {
        /// Just past the last character the new line follows.
        let end: String.Index
        /// One newline after an existing entry, two under a bare heading.
        let separator: String
    }

    /// The end of the last entry under `### Ca đã ghi`, or of the heading
    /// itself when nothing is listed yet.
    private static func anchor(in text: String) -> Anchor? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let heading = lines.firstIndex(where: { trimmed($0) == subHeading }) else { return nil }
        var lastEntry: Substring?
        var index = lines.index(after: heading)
        while index < lines.endIndex {
            let line = lines[index]
            if trimmed(line).hasPrefix("#") { break }
            if !trimmed(line).isEmpty { lastEntry = line }
            index = lines.index(after: index)
        }
        guard let lastEntry else { return Anchor(end: lines[heading].endIndex, separator: "\n\n") }
        return Anchor(end: lastEntry.endIndex, separator: "\n")
    }

    /// No `### Ca đã ghi` yet: it goes at the end of `## Index ca`, or — in a
    /// file that has no index section at all — at the end of the file, together
    /// with the section heading.
    private static func appendingSection(_ line: String, to text: String) -> String {
        let block = "\(subHeading)\n\n\(line)\n"
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let heading = lines.firstIndex(where: { trimmed($0) == sectionHeading }) else {
            return separated(text) + "\(sectionHeading)\n\n" + block
        }
        var lastLine = lines[heading]
        var index = lines.index(after: heading)
        while index < lines.endIndex {
            let candidate = lines[index]
            if isTopLevelHeading(candidate) { break }
            if !trimmed(candidate).isEmpty { lastLine = candidate }
            index = lines.index(after: index)
        }
        var updated = text
        updated.replaceSubrange(lastLine.endIndex..<lastLine.endIndex, with: "\n\n" + block.dropLast())
        return updated
    }

    /// A `#` or `##` heading — the end of the index section. `###` belongs to
    /// it, so it does not stop the scan.
    private static func isTopLevelHeading(_ line: Substring) -> Bool {
        let value = trimmed(line)
        return value.hasPrefix("# ") || value.hasPrefix("## ")
    }

    private static func trimmed(_ line: Substring) -> String {
        line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A file ended so the appended block starts after one blank line.
    private static func separated(_ text: String) -> String {
        if text.isEmpty { return "" }
        if text.hasSuffix("\n\n") { return text }
        return text.hasSuffix("\n") ? text + "\n" : text + "\n\n"
    }

    // MARK: - Field shaping

    /// The first sentence of the direction, which is what the index is for:
    /// scanning past cases without opening every file.
    private static func firstSentence(_ text: String, limit: Int = 180) -> String {
        let flat = oneLine(text)
        var sentence = flat
        for (offset, character) in flat.enumerated() where ".!?".contains(character) {
            let next = flat.index(flat.startIndex, offsetBy: offset + 1)
            // A decimal point inside `5.6` is not the end of a sentence.
            if next == flat.endIndex || flat[next] == " " {
                sentence = String(flat[..<flat.index(flat.startIndex, offsetBy: offset)])
                break
            }
        }
        guard sentence.count > limit else { return sentence }
        return String(sentence.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func oneLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
