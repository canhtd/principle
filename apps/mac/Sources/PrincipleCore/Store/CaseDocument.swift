import Foundation

/// The markdown of one case file, composed from the trailer's `case` object.
///
/// The file belongs to the repo's memory protocol, not to the app: a terminal
/// `/ask-ray` session reads and continues the same files, so the headings are
/// `memory/cases/_TEMPLATE.md`'s own and stay Vietnamese. The template is read
/// off disk when it is there — a repo that changes its template gets its
/// template — and the copy below is the fallback for a repo that has none.
enum CaseDocument {
    /// The template's section headings, in order. Each one has a slot in
    /// ``sections(for:principleLines:)``, so the two lists must stay the same
    /// length; a template with a different count is not remapped, it is ignored.
    static let builtInHeadings = [
        "## Vấn đề (một câu, bằng lời của anh)",
        "## Vấn đề thật (nếu khác vấn đề được kể)",
        "## Nguyên tắc đã áp",
        "## Hướng đã chốt",
        "## Cái giá phải trả",
        "## Điều kiện lật",
        "## Follow-up",
        "## Kết quả",
    ]

    /// What a later turn of the same consult appends.
    static let updateHeadingPrefix = "## Cập nhật"

    // MARK: - Dates

    /// `YYYY-MM-DD` in the reader's own calendar: the case is filed on the day
    /// they had the conversation, not the day UTC was having.
    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: - Composing

    /// The headings to write: the template's own when it has exactly the set
    /// this composer knows how to fill, otherwise the built-in copy.
    static func headings(fromTemplate template: String?) -> [String] {
        guard let template else { return builtInHeadings }
        let found = template.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("## ") }
        return found.count == builtInHeadings.count ? found : builtInHeadings
    }

    /// The whole file. Sections the engine said nothing about keep their
    /// heading and stay empty — `Kết quả` always does, because it is filled in
    /// only when a real outcome arrives (CLAUDE.md).
    static func render(
        summary: CaseSummary,
        diagnosis: Diagnosis?,
        principleLines: [String],
        headings: [String],
        date: Date,
        calendar: Calendar = .current
    ) -> String {
        var blocks = ["# \(summary.fileSlug)", frontMatter(summary, diagnosis, day(date, calendar: calendar))]
        let bodies = sections(for: summary, principleLines: principleLines)
        for (heading, body) in zip(headings, bodies) {
            blocks.append(heading)
            if !body.isEmpty { blocks.append(body) }
        }
        return blocks.joined(separator: "\n\n") + "\n"
    }

    /// The block a later turn appends: what changed, and nothing that would
    /// rewrite what the first turn settled.
    static func updateSection(summary: CaseSummary, date: Date, calendar: Calendar = .current) -> String {
        var blocks: [String] = []
        if !summary.direction.isEmpty { blocks.append(summary.direction) }
        if !summary.flip.isEmpty { blocks.append("**Điều kiện lật:** \(summary.flip)") }
        if !summary.followUp.isEmpty { blocks.append("**Follow-up:** \(summary.followUp)") }
        guard !blocks.isEmpty else { return "" }
        let heading = "\(updateHeadingPrefix) \(day(date, calendar: calendar))"
        return ([heading] + blocks).joined(separator: "\n\n") + "\n"
    }

    /// One line per cited principle: the id, the corpus title verbatim, and the
    /// bridge the engine wrote. A title the corpus does not know is left out
    /// rather than invented (AE2).
    static func principleLines(_ principles: [PrincipleRef], corpus: CorpusStore) -> [String] {
        principles.map { reference in
            let title = corpus.principle(id: reference.id)?.title ?? ""
            let parts = ["`\(reference.id)`", oneLine(title), oneLine(reference.apply)]
            return "- " + parts.filter { !$0.isEmpty }.joined(separator: " — ")
        }
    }

    // MARK: - Pieces

    private static func frontMatter(_ summary: CaseSummary, _ diagnosis: Diagnosis?, _ day: String) -> String {
        [
            "- **Ngày:** \(day)",
            "- **Kiểu ca:** \(value(diagnosis?.kind ?? ""))",
            "- **Trạng thái:** mở",
            "- **Liên quan goal:** \(value(summary.goal))",
            "- **Tiếp nối ca:** \(value(summary.continues))",
        ].joined(separator: "\n")
    }

    /// Positional, in the order of ``builtInHeadings``.
    private static func sections(for summary: CaseSummary, principleLines: [String]) -> [String] {
        [
            summary.problem,
            summary.realProblem,
            principleLines.joined(separator: "\n"),
            summary.direction,
            summary.price,
            summary.flip,
            summary.followUp,
            // Kết quả: left blank on purpose, filled only by a real outcome.
            "",
        ]
    }

    private static func value(_ text: String) -> String {
        let trimmed = oneLine(text)
        return trimmed.isEmpty ? "—" : trimmed
    }

    /// Whatever the engine wrote, on one line: these go into a markdown bullet
    /// or a bold label, and a stray newline there breaks the list.
    private static func oneLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
