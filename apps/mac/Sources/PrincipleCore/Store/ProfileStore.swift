import Foundation

/// Reading and writing the profile section of `<repo>/memory/MEMORY.md`.
///
/// Every consult begins with the engine reading MEMORY.md, and `## Hồ sơ người
/// hỏi` is the part of it that describes the person rather than the past cases.
/// The heading stays Vietnamese because the file belongs to the skill, not to
/// the app — renaming it here would leave the engine reading an empty profile.
///
/// The file is shared with terminal sessions and hand edits, so a save rewrites
/// that one section and leaves every other byte alone. The repo path is
/// injected, never hardcoded.
public struct ProfileStore: Sendable {
    /// Where the file lives, relative to the repo root.
    public static let relativePath = "memory/MEMORY.md"
    /// The heading the skill looks for. Matched against a whole line.
    public static let sectionHeading = "## Hồ sơ người hỏi"
    /// Title written only when the file has to be created from nothing.
    public static let defaultTitle = "# MEMORY"

    public let repoURL: URL

    public init(repoURL: URL) {
        self.repoURL = repoURL
    }

    public var fileURL: URL {
        Self.relativePath.split(separator: "/").reduce(repoURL) { $0.appendingPathComponent(String($1)) }
    }

    // MARK: - Read

    /// The section body, trimmed. A missing file, a missing section and an
    /// unreadable file all read as empty — the editor shows a blank profile
    /// rather than an error the reader cannot act on. A *save* tells the three
    /// apart, because only there does the difference cost something.
    public func load() -> String {
        guard let text = readText(), let section = Self.section(in: text) else { return "" }
        return String(text[section.body]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Write

    /// Rewrites the section and nothing else. Creates the file, or inserts the
    /// section under the title, when either is missing.
    public func save(_ body: String) throws {
        let existing = try existingText()
        let updated = Self.replacingBody(
            with: body.trimmingCharacters(in: .whitespacesAndNewlines),
            in: existing
        )
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // `.atomic` is temp-file-then-replace: a half-written MEMORY.md would
        // cost the profile *and* the case index the same file holds.
        try Data(updated.utf8).write(to: fileURL, options: .atomic)
    }

    /// The file as it stands, or a skeleton when there is none. An existing
    /// file that cannot be read throws rather than being overwritten with that
    /// skeleton — the case index lives in the same file.
    private func existingText() throws -> String {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return "\(Self.defaultTitle)\n\n\(Self.sectionHeading)\n"
        }
        guard let text = readText() else { throw ProfileStoreError.unreadable(fileURL) }
        return text
    }

    private func readText() -> String? {
        guard let data = try? Data(contentsOf: fileURL), let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return Self.normalized(text)
    }

    /// The file is written LF-only. A CRLF copy is normalised on the way in, so
    /// a `\r` can never end up inside a heading match or a saved line.
    static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    // MARK: - Section arithmetic

    /// Where the section body sits, plus the two facts that decide how much
    /// blank line a rewritten section needs around it.
    struct Section {
        /// From just after the heading line to the start of the next `## `.
        let body: Range<String.Index>
        /// The heading is the last line and nothing terminates it.
        let headingUnterminated: Bool
        /// No further `## ` heading follows, so the body ends the file.
        let isLast: Bool
    }

    static func section(in text: String) -> Section? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let heading = lines.firstIndex(where: { isSectionHeading($0) }) else { return nil }
        let after = lines.index(after: heading)
        guard after < lines.endIndex else {
            return Section(body: text.endIndex..<text.endIndex, headingUnterminated: true, isLast: true)
        }
        let next = lines[after...].firstIndex { $0.hasPrefix("## ") }
        let end = next.map { lines[$0].startIndex } ?? text.endIndex
        return Section(body: lines[after].startIndex..<end, headingUnterminated: false, isLast: next == nil)
    }

    private static func isSectionHeading(_ line: Substring) -> Bool {
        line.trimmingCharacters(in: .whitespaces) == sectionHeading
    }

    /// The section body replaced in place. Everything outside the returned
    /// range — title, other sections, the case index, trailing newline — comes
    /// through untouched. A file with no section at all is not rewritten but
    /// added to.
    static func replacingBody(with body: String, in text: String) -> String {
        guard let section = section(in: text) else { return inserting(body, into: text) }
        let replacement: String
        if body.isEmpty {
            replacement = "\n"
        } else {
            // A blank line under the heading, and one before whatever follows.
            let lead = section.headingUnterminated ? "\n\n" : "\n"
            replacement = lead + body + (section.isLast ? "\n" : "\n\n")
        }
        var updated = text
        updated.replaceSubrange(section.body, with: replacement)
        return updated
    }

    /// The section spliced in whole — heading *and* body in one write.
    ///
    /// Written this way because the two-step version cost data: inserting a
    /// bare heading and then deriving a body range made whatever prose already
    /// sat there the section's body, and the save overwrote it. For the same
    /// reason the block goes in above the first `## ` heading — the profile is
    /// what the engine reads first — but below any prose under the title,
    /// which stays outside the section and out of reach of the next save.
    static func inserting(_ body: String, into text: String) -> String {
        let block = body.isEmpty ? "\(sectionHeading)\n" : "\(sectionHeading)\n\n\(body)\n"
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let next = lines.firstIndex(where: { $0.hasPrefix("## ") }) else {
            // Nothing to sit above: the section becomes the tail of the file.
            return separated(trimmingTrailingNewlines(text)) + block
        }
        let start = lines[next].startIndex
        return separated(String(text[..<start])) + block + "\n" + String(text[start...])
    }

    /// A prefix ended so the next block starts after one blank line. Empty
    /// stays empty: nothing precedes a section written at the top of a file.
    private static func separated(_ prefix: String) -> String {
        if prefix.isEmpty || prefix.hasSuffix("\n\n") { return prefix }
        return prefix.hasSuffix("\n") ? prefix + "\n" : prefix + "\n\n"
    }

    private static func trimmingTrailingNewlines(_ text: String) -> String {
        var trimmed = text
        while trimmed.hasSuffix("\n") { trimmed.removeLast() }
        return trimmed
    }
}

/// The one failure worth naming: the file is there but cannot be read, so a
/// save would replace real content with a skeleton.
public enum ProfileStoreError: LocalizedError, Equatable {
    case unreadable(URL)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let url):
            "Could not read \(url.path). Fix the file's permissions or encoding, then try again."
        }
    }
}
