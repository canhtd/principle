import Foundation

/// The case file dictated in the trailer, in the same line as the cards.
///
/// The memory loop of this repo is closed by `memory/cases/<file>.md` plus one
/// line in the index. Having the engine compose that file with `Write` cost a
/// measured 29 s of one turn — about 30 % of it — before the answer could start,
/// and a small model sometimes skipped the write altogether. So the engine
/// dictates the fields below in the line it was already going to emit, and the
/// app does the writing (``CaseFileStore``).
///
/// Every field is optional on the wire and decodes to an empty string: half a
/// case is still a case worth filing, and no missing key may cost the consult.
public struct CaseSummary: Codable, Equatable, Sendable {
    /// ascii-kebab, at most six words — becomes `YYYY-MM-DD-<slug>.md`.
    public let slug: String
    /// The problem in one sentence, in the asker's own words.
    public let problem: String
    /// The problem underneath, when it differs from the one told.
    public let realProblem: String
    /// The direction settled on: one to three sentences of concrete action.
    public let direction: String
    /// What it costs.
    public let price: String
    /// What would have to show up to reverse the direction.
    public let flip: String
    /// `YYYY-MM-DD`, or empty when nothing was scheduled.
    public let followUp: String
    /// A goal in `GOALS.md` this case touches, or `—`.
    public let goal: String
    /// The earlier case file this one continues, or `—`.
    public let continues: String

    public init(
        slug: String = "",
        problem: String = "",
        realProblem: String = "",
        direction: String = "",
        price: String = "",
        flip: String = "",
        followUp: String = "",
        goal: String = "",
        continues: String = ""
    ) {
        self.slug = slug
        self.problem = problem
        self.realProblem = realProblem
        self.direction = direction
        self.price = price
        self.flip = flip
        self.followUp = followUp
        self.goal = goal
        self.continues = continues
    }

    private enum CodingKeys: String, CodingKey {
        case slug, problem, direction, price, flip, goal, continues
        case realProblem = "real_problem"
        case followUp = "follow_up"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func field(_ key: CodingKeys) -> String {
            (try? container.decodeIfPresent(String.self, forKey: key)) ?? ""
        }
        slug = field(.slug)
        problem = field(.problem)
        realProblem = field(.realProblem)
        direction = field(.direction)
        price = field(.price)
        flip = field(.flip)
        followUp = field(.followUp)
        goal = field(.goal)
        continues = field(.continues)
    }

    /// Trimmed, with the placeholders the prompt allows (`—`, `-`) read as "not
    /// said" — or `nil` when the engine dictated nothing at all. The app never
    /// files a case the engine did not describe (AE2).
    public var cleaned: CaseSummary? {
        let summary = CaseSummary(
            slug: Self.trimmed(slug),
            problem: Self.trimmed(problem),
            realProblem: Self.said(realProblem),
            direction: Self.trimmed(direction),
            price: Self.said(price),
            flip: Self.said(flip),
            followUp: Self.said(followUp),
            goal: Self.said(goal),
            continues: Self.said(continues)
        )
        return summary.isEmpty ? nil : summary
    }

    /// Nothing worth writing a file about.
    public var isEmpty: Bool {
        [slug, problem, realProblem, direction, price, flip, followUp]
            .allSatisfy { Self.trimmed($0).isEmpty }
    }

    /// The filename stem, without the date: the dictated slug when it survives
    /// being reduced to ascii, otherwise one made from the problem sentence.
    public var fileSlug: String {
        for candidate in [slug, problem, direction] {
            let made = Self.kebab(candidate)
            if !made.isEmpty { return made }
        }
        return "ca"
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// An em dash or a hyphen on its own is the prompt's way of saying "none".
    private static func said(_ text: String) -> String {
        let value = trimmed(text)
        return ["—", "-", "–", "n/a", "N/A"].contains(value) ? "" : value
    }

    /// ascii-kebab, capped at six words. Vietnamese is transliterated rather
    /// than dropped, so `bỏ thuốc lá` becomes `bo-thuoc-la` and not `b`.
    static func kebab(_ text: String, wordLimit: Int = 6) -> String {
        let latin = text.applyingTransform(StringTransform("Any-Latin; Latin-ASCII"), reverse: false) ?? text
        let ascii = String(latin.lowercased().map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : " " })
        let words = ascii.split(separator: " ").prefix(wordLimit).map(String.init)
        return words.joined(separator: "-")
    }
}
