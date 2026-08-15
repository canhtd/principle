import Foundation

/// The repo files a consult would otherwise spend its first round trips reading.
///
/// Measured on one fixture consult (opus): `memory/MEMORY.md`, `goals/GOALS.md`
/// and `memory/cases/_TEMPLATE.md` cost three separate `Read` calls plus a
/// directory listing — about 7 s of a 96 s turn — before the engine had begun to
/// diagnose anything. The app already owns the repo those files live in, so it
/// hands them over inside the prompt it was going to send anyway.
///
/// Only the turn that opens an engine session carries them. `--resume` keeps the
/// text in the engine's own context, and repeating it every turn would pay for the
/// same tokens again on each one.
///
/// The case file at the other end of the loop is not asked for here at all: the
/// app writes it from the trailer's `case` object (``CaseFileStore``). The header
/// says so, so an engine handed the memory does not spend a `Write` on it.
public struct RepoContext: Sendable, Equatable {
    public var memory: String?
    public var goals: String?
    public var caseTemplate: String?

    /// A repo with no memory loop in it — the prompt then looks exactly as it did
    /// before this existed.
    public static let empty = RepoContext()

    /// Big enough for a real MEMORY.md, small enough that a repo that let one file
    /// grow without bound cannot push the question itself out of the model's
    /// attention.
    static let byteCap = 8 * 1024

    public init(memory: String? = nil, goals: String? = nil, caseTemplate: String? = nil) {
        self.memory = memory
        self.goals = goals
        self.caseTemplate = caseTemplate
    }

    /// Reads what is there. A missing file is not an error — plenty of repos have
    /// no `goals/` at all, and the engine is still told to write the case file.
    public static func read(at repoURL: URL) -> RepoContext {
        RepoContext(
            memory: contents(of: repoURL.appendingPathComponent("memory/MEMORY.md")),
            goals: contents(of: repoURL.appendingPathComponent("goals/GOALS.md")),
            caseTemplate: contents(of: repoURL.appendingPathComponent("memory/cases/_TEMPLATE.md"))
        )
    }

    /// What the pre-read files are introduced with.
    ///
    /// Its own constant, spelled without interpolation or line continuations:
    /// `Tests/E2E/e2e-smoke.sh` reads this literal straight out of the source so
    /// the real-engine run is given the same header the app gives it, and either
    /// would reach the engine as raw `\(...)` backslashes. A test keeps it clean.
    public static let header = """
        App đã đọc sẵn các file dưới đây từ repo — dùng luôn, đừng gọi Read cho chúng
        nữa. File ca trong memory/cases/ và dòng index trong memory/MEMORY.md thì app tự
        ghi từ trường `case` của dòng trailer, nên đừng Write hay Edit hai chỗ đó.
        """

    /// The block appended to the opening prompt, empty when there was nothing to
    /// read.
    var promptSection: String {
        let sections = [
            Self.section("Nội dung memory/MEMORY.md hiện tại", memory),
            Self.section("Nội dung goals/GOALS.md hiện tại", goals),
            Self.section("Nội dung memory/cases/_TEMPLATE.md", caseTemplate),
        ].compactMap { $0 }
        guard !sections.isEmpty else { return "" }
        return "\(Self.header)\n\n\(sections.joined(separator: "\n\n"))"
    }

    private static func section(_ title: String, _ body: String?) -> String? {
        guard let body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return """
            --- \(title) ---
            \(body)
            --- hết ---
            """
    }

    private static func contents(of url: URL) -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return capped(text)
    }

    /// Cuts on bytes, not characters: the cap exists to bound what goes over the
    /// wire, and Vietnamese runs two to three bytes a character. A cut landing
    /// inside one decodes to U+FFFD, which is dropped rather than shipped.
    private static func capped(_ text: String) -> String {
        guard text.utf8.count > byteCap else { return text }
        var head = String(decoding: text.utf8.prefix(byteCap), as: UTF8.self)
        while head.last == "\u{FFFD}" { head.removeLast() }
        return head + "\n…(app đã cắt bớt phần còn lại — đọc file nếu cần đủ)"
    }
}
