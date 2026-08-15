import Foundation
import Testing

@testable import PrincipleCore

/// Every read here is from a throwaway repo: the real `memory/` is personal data
/// and no test may touch it.
@Suite("repo context")
struct RepoContextTests {
    private func write(_ text: String, to path: String, in repo: TempRepo) throws {
        let url = repo.root.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test("The three files the engine used to open one Read at a time")
    func readsTheMemoryFiles() throws {
        let repo = try TempRepo(prefix: "repo-context")
        try write("# MEMORY\nHồ sơ.", to: "memory/MEMORY.md", in: repo)
        try write("# GOALS\nMục tiêu.", to: "goals/GOALS.md", in: repo)
        try write("# Ca\n- Ngày:", to: "memory/cases/_TEMPLATE.md", in: repo)

        let context = RepoContext.read(at: repo.root)

        #expect(context.memory?.contains("Hồ sơ.") == true)
        #expect(context.goals?.contains("Mục tiêu.") == true)
        #expect(context.caseTemplate?.contains("- Ngày:") == true)
    }

    @Test("A repo with no memory loop reads as nothing, not as an error")
    func missingFilesAreNotAnError() throws {
        let repo = try TempRepo(prefix: "repo-context-empty")

        let context = RepoContext.read(at: repo.root)

        #expect(context == .empty)
        #expect(context.promptSection.isEmpty)
    }

    @Test("Each file is fenced under a header the engine can see it by")
    func sectionsAreLabelled() {
        let section = RepoContext(memory: "Hồ sơ.", goals: "Mục tiêu.").promptSection

        #expect(section.contains("--- Nội dung memory/MEMORY.md hiện tại ---"))
        #expect(section.contains("Hồ sơ."))
        #expect(section.contains("--- Nội dung goals/GOALS.md hiện tại ---"))
        #expect(section.contains("Mục tiêu."))
        #expect(section.contains("--- hết ---"))
        // Nothing was read for the template, so it gets no empty section.
        #expect(!section.contains("_TEMPLATE.md"))
    }

    /// Handing the memory over saves the reads; it must not be read as permission
    /// to skip the write that closes the loop.
    @Test("The header still orders the case file to be written")
    func theWriteIsStillOrdered() {
        let section = RepoContext(memory: "Hồ sơ.").promptSection

        #expect(section.contains("đừng gọi Read"))
        #expect(section.contains("GHI file ca vào memory/cases/"))
        #expect(section.hasPrefix(RepoContext.header))
        // e2e-smoke.sh reads the header out of the source with awk, so an
        // interpolation would reach a real engine as the literal `\(...)`.
        #expect(!RepoContext.header.contains("\\("))
    }

    @Test("A file with nothing but whitespace in it is left out")
    func blankFilesAreSkipped() {
        #expect(RepoContext(memory: "\n  \n").promptSection.isEmpty)
    }

    @Test("An oversized file is cut on a byte budget, with the cut announced")
    func longFilesAreCapped() throws {
        let repo = try TempRepo(prefix: "repo-context-cap")
        // Vietnamese: two to three bytes a character, so the cut lands inside one.
        let long = String(repeating: "Nguyên tắc đầy đủ. ", count: 2000)
        try write(long, to: "memory/MEMORY.md", in: repo)
        #expect(long.utf8.count > RepoContext.byteCap * 2)

        let memory = try #require(RepoContext.read(at: repo.root).memory)

        #expect(memory.utf8.count < RepoContext.byteCap + 200)
        #expect(memory.contains("app đã cắt bớt"))
        // A cut mid-character must not ship as U+FFFD.
        #expect(!memory.contains("\u{FFFD}"))
    }

    @Test("A file that fits is passed through unchanged")
    func shortFilesAreUntouched() throws {
        let repo = try TempRepo(prefix: "repo-context-short")
        try write("# MEMORY\nĐủ ngắn.", to: "memory/MEMORY.md", in: repo)

        #expect(RepoContext.read(at: repo.root).memory == "# MEMORY\nĐủ ngắn.")
    }
}
