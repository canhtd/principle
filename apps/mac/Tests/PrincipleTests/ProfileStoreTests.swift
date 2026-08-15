import Foundation
import Testing

@testable import PrincipleCore

@Suite("ProfileStore")
struct ProfileStoreTests {
    // MARK: - 1. Reading the section

    @Test("Load returns the profile section body, trimmed")
    func loadReturnsTheSectionBody() throws {
        let repo = try TempRepo(prefix: "profile")
        try repo.writeMemory(TempRepo.memoryFixture)

        #expect(repo.profile.fileURL.path.hasSuffix("memory/MEMORY.md"))
        #expect(
            repo.profile.load() == """
                - **Anh Danny** — PM dẫn một team nhỏ AI-native.
                - Trao đổi bằng tiếng Việt, xưng "anh".
                """
        )
    }

    @Test("A section that runs to the end of the file still loads")
    func loadReadsTheLastSection() throws {
        let repo = try TempRepo(prefix: "profile")
        try repo.writeMemory("# MEMORY\n\n## Hồ sơ người hỏi\n\n- one\n- two\n")

        #expect(repo.profile.load() == "- one\n- two")
    }

    @Test("Missing file and missing section both read as empty")
    func loadOfAnAbsentProfileIsEmpty() throws {
        let repo = try TempRepo(prefix: "profile")
        #expect(repo.profile.load().isEmpty)

        try repo.writeMemory("# MEMORY\n\n## Index ca\n\n- a case\n")
        #expect(repo.profile.load().isEmpty)
    }

    @Test("A `# ` heading inside the section does not end it")
    func onlyAnH2EndsTheSection() throws {
        let repo = try TempRepo(prefix: "profile")
        try repo.writeMemory("# MEMORY\n\n## Hồ sơ người hỏi\n\n- one\n\n# Aside\n\n- two\n\n## Index ca\n")

        #expect(repo.profile.load() == "- one\n\n# Aside\n\n- two")
    }

    // MARK: - 2. Saving touches one section only

    @Test("Save rewrites the profile and leaves every other section intact")
    func savePreservesTheRestOfTheFile() throws {
        let repo = try TempRepo(prefix: "profile")
        try repo.writeMemory(TempRepo.memoryFixture)

        try repo.profile.save("- Rewritten profile.\n- Second line.")

        let text = try repo.memoryText()
        #expect(
            text == """
                # MEMORY — đọc file này trước khi chẩn đoán bất kỳ ca nào

                ## Hồ sơ người hỏi

                - Rewritten profile.
                - Second line.

                ## Chủ đề lặp lại

                *(Chưa đủ dữ liệu.)*

                ## Index ca

                - 2026-08-15 · bo-thuoc-la · mở

                """
        )
        // The case index is the part a lost byte would cost most.
        #expect(text.contains("- 2026-08-15 · bo-thuoc-la · mở"))
        #expect(repo.profile.load() == "- Rewritten profile.\n- Second line.")
    }

    @Test("Saving the last section keeps a single trailing newline")
    func saveOfTheLastSectionEndsWithOneNewline() throws {
        let repo = try TempRepo(prefix: "profile")
        try repo.writeMemory("# MEMORY\n\n## Index ca\n\n- a case\n\n## Hồ sơ người hỏi\n\n- old\n")

        try repo.profile.save("- new")

        #expect(try repo.memoryText() == "# MEMORY\n\n## Index ca\n\n- a case\n\n## Hồ sơ người hỏi\n\n- new\n")
    }

    @Test("Saving an empty profile leaves the heading and the other sections")
    func saveOfAnEmptyBodyKeepsTheHeading() throws {
        let repo = try TempRepo(prefix: "profile")
        try repo.writeMemory(TempRepo.memoryFixture)

        try repo.profile.save("   \n\n  ")

        let text = try repo.memoryText()
        #expect(text.contains("## Hồ sơ người hỏi\n\n## Chủ đề lặp lại"))
        #expect(text.contains("- 2026-08-15 · bo-thuoc-la · mở"))
        #expect(repo.profile.load().isEmpty)
    }
}
