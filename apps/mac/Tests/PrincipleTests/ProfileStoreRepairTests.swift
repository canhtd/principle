import Foundation
import Testing

@testable import PrincipleCore

@Suite("ProfileStore — repairing a file")
struct ProfileStoreRepairTests {
    // MARK: - 1. Creating what is not there

    @Test("Missing file is created with a title and the section")
    func saveCreatesTheFile() throws {
        let repo = try TempRepo(prefix: "profile")
        #expect(!FileManager.default.fileExists(atPath: repo.profile.fileURL.path))

        try repo.profile.save("- brand new")

        #expect(try repo.memoryText() == "# MEMORY\n\n## Hồ sơ người hỏi\n\n- brand new\n")
        #expect(repo.profile.load() == "- brand new")
    }

    @Test("Missing section is inserted after the title, above the other sections")
    func saveInsertsTheSectionAfterTheTitle() throws {
        let repo = try TempRepo(prefix: "profile")
        try repo.writeMemory("# MEMORY\n\n## Index ca\n\n- a case\n")

        try repo.profile.save("- inserted")

        #expect(
            try repo.memoryText() == """
                # MEMORY

                ## Hồ sơ người hỏi

                - inserted

                ## Index ca

                - a case

                """
        )
    }

    @Test("No title at all: the section goes to the top of the file")
    func saveWithoutATitlePutsTheSectionFirst() throws {
        let repo = try TempRepo(prefix: "profile")
        try repo.writeMemory("## Index ca\n\n- a case\n")

        try repo.profile.save("- inserted")

        #expect(try repo.memoryText() == "## Hồ sơ người hỏi\n\n- inserted\n\n## Index ca\n\n- a case\n")
    }

    @Test("A file that is only a title, with no trailing newline")
    func saveIntoATitleOnlyFile() throws {
        let repo = try TempRepo(prefix: "profile")
        try repo.writeMemory("# MEMORY")

        try repo.profile.save("- inserted")

        #expect(try repo.memoryText() == "# MEMORY\n\n## Hồ sơ người hỏi\n\n- inserted\n")
    }

    @Test("A file ending on the heading itself")
    func saveIntoAFileEndingOnTheHeading() throws {
        let repo = try TempRepo(prefix: "profile")
        try repo.writeMemory("# MEMORY\n\n## Hồ sơ người hỏi")

        try repo.profile.save("- inserted")

        #expect(try repo.memoryText() == "# MEMORY\n\n## Hồ sơ người hỏi\n\n- inserted\n")
    }

    // MARK: - 2. Round trip and line endings

    @Test("Save is idempotent: saving what was loaded changes nothing")
    func roundTripIsIdempotent() throws {
        let repo = try TempRepo(prefix: "profile")
        try repo.writeMemory(TempRepo.memoryFixture)

        try repo.profile.save(repo.profile.load())
        let once = try repo.memoryText()
        #expect(once == TempRepo.memoryFixture)

        try repo.profile.save(repo.profile.load())
        #expect(try repo.memoryText() == once)
    }

    @Test("A CRLF file loads without carriage returns and is written back LF-only")
    func crlfIsNormalisedAway() throws {
        let repo = try TempRepo(prefix: "profile")
        try repo.writeMemory(
            TempRepo.memoryFixture.replacingOccurrences(of: "\n", with: "\r\n"))

        let loaded = repo.profile.load()
        #expect(!loaded.contains("\r"))
        #expect(loaded == "- **Anh Danny** — PM dẫn một team nhỏ AI-native.\n- Trao đổi bằng tiếng Việt, xưng \"anh\".")

        try repo.profile.save(loaded + "\n- third line")
        let text = try repo.memoryText()
        #expect(!text.contains("\r"))
        #expect(text.contains("- third line\n\n## Chủ đề lặp lại"))
        #expect(text.contains("- 2026-08-15 · bo-thuoc-la · mở"))
    }

    @Test("Body is trimmed on the way in, so stray blank lines do not accumulate")
    func saveTrimsTheBody() throws {
        let repo = try TempRepo(prefix: "profile")
        try repo.writeMemory(TempRepo.memoryFixture)

        try repo.profile.save("\n\n  - padded  \n  - kept  \n\n\n")

        // Only the edges are trimmed — indentation inside the body survives,
        // because a nested markdown bullet depends on it.
        #expect(try repo.memoryText().contains("## Hồ sơ người hỏi\n\n- padded  \n  - kept\n\n## Chủ đề lặp lại"))
        #expect(repo.profile.load() == "- padded  \n  - kept")
    }

    // MARK: - 3. Failure

    @Test("An unreadable file is not overwritten with a fresh skeleton")
    func saveRefusesToClobberAnUnreadableFile() throws {
        let repo = try TempRepo(prefix: "profile")
        // Invalid UTF-8: the file is there, so a save must not treat it as absent.
        let url = repo.profile.fileURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0xFF, 0xFE, 0x00, 0x41]).write(to: url)

        #expect(throws: ProfileStoreError.unreadable(url)) { try repo.profile.save("- new") }
        #expect(try Data(contentsOf: url) == Data([0xFF, 0xFE, 0x00, 0x41]))
    }
}
