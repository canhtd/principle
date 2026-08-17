import Foundation
import Testing

@testable import PrincipleCore

/// The index line every filed case adds to `memory/MEMORY.md` — the file that
/// also holds the profile a terminal session hand-edits, which is why every test
/// here checks what was *not* rewritten as much as what was.
@Suite("CaseFileStore — index trong MEMORY.md")
struct CaseIndexTests {
    private let expectedLine = "- 2026-08-15 · [tri-hoan-viec-nho](cases/2026-08-15-tri-hoan-viec-nho.md)"
        + " · Ca ưu tiên · Chốt ba mục tiêu quý · mở (follow-up 2026-08-22)"

    @Test("Thêm đúng một dòng vào cuối mục Ca đã ghi, phần còn lại y nguyên từng byte")
    func appendsOneLineAndRewritesNothingElse() throws {
        let repo = try TempRepo(prefix: "case-index")
        try repo.writeMemory(TempRepo.memoryWithCaseIndex)

        try repo.caseStore.create(caseFixture, diagnosis: caseDiagnosis, date: TempRepo.noon(august: 15))

        #expect(try repo.memoryText() == TempRepo.memoryWithCaseIndex + expectedLine + "\n")
    }

    @Test("Chưa có mục Ca đã ghi thì tạo mục đó dưới Index ca")
    func createsTheSubHeadingWhenMissing() throws {
        let repo = try TempRepo(prefix: "case-index-heading")
        try repo.writeMemory(TempRepo.memoryFixture)

        try repo.caseStore.create(caseFixture, diagnosis: caseDiagnosis, date: TempRepo.noon(august: 15))

        let expected = TempRepo.memoryFixture.dropLast()
            + "\n\n\(CaseIndex.subHeading)\n\n\(expectedLine)\n"
        #expect(try repo.memoryText() == String(expected))
    }

    @Test("MEMORY.md chưa có mục Index ca nào thì dựng cả hai đề mục ở cuối file")
    func createsTheIndexSectionWhenMissing() throws {
        let repo = try TempRepo(prefix: "case-index-section")
        let memory = "# MEMORY\n\n## Hồ sơ người hỏi\n\n- **Anh Danny** — PM.\n"
        try repo.writeMemory(memory)

        try repo.caseStore.create(caseFixture, diagnosis: caseDiagnosis, date: TempRepo.noon(august: 15))

        #expect(
            try repo.memoryText()
                == memory + "\n\(CaseIndex.sectionHeading)\n\n\(CaseIndex.subHeading)\n\n\(expectedLine)\n")
    }

    @Test("Repo chưa có MEMORY.md thì file được tạo cùng dòng index đầu tiên")
    func createsTheFileWhenTheRepoHasNone() throws {
        let repo = try TempRepo(prefix: "case-index-new")

        try repo.caseStore.create(caseFixture, diagnosis: caseDiagnosis, date: TempRepo.noon(august: 15))

        let text = try repo.memoryText()
        #expect(text.hasPrefix(ProfileStore.defaultTitle))
        #expect(text.contains(CaseIndex.subHeading))
        #expect(text.hasSuffix(expectedLine + "\n"))
    }

    /// The profile a terminal session hand-edits lives in the same file, so a
    /// filing may only insert.
    @Test("Phần hồ sơ và mọi mục khác không bị đụng tới")
    func leavesTheProfileAlone() throws {
        let repo = try TempRepo(prefix: "case-index-profile")
        try repo.writeMemory(TempRepo.memoryWithCaseIndex)

        try repo.caseStore.create(caseFixture, diagnosis: caseDiagnosis, date: TempRepo.noon(august: 15))

        #expect(repo.profile.load() == "- **Anh Danny** — PM dẫn một team nhỏ.")
        #expect(try repo.memoryText().contains("Format: `ngày · slug"))
    }

    // MARK: - Resume turns

    /// One session is one case: the follow-up turn adds to the same file and
    /// leaves the index at one line, or a two-turn consult doubles in the index.
    @Test("Lượt sau ghi thêm mục Cập nhật vào đúng file ca, không thêm dòng index")
    func resumeAppendsAnUpdateAndNoSecondLine() throws {
        let repo = try TempRepo(prefix: "case-resume")
        try repo.writeMemory(TempRepo.memoryWithCaseIndex)
        let filed = try repo.caseStore.create(caseFixture, diagnosis: caseDiagnosis, date: TempRepo.noon(august: 15))
        let indexAfterFirstTurn = try repo.memoryText()

        try repo.caseStore.appendUpdate(
            CaseSummary(direction: "Hạn lùi ba tuần thì làm log trước, chốt mục tiêu sau.",
                        flip: "Log năm ngày không ra tín hiệu nào.",
                        followUp: "2026-09-05"),
            toCaseAt: filed.relativePath,
            date: TempRepo.noon(august: 16))

        let text = try repo.fileText(at: filed.relativePath)
        #expect(text.contains("\n## Cập nhật 2026-08-16\n"))
        #expect(text.contains("Hạn lùi ba tuần thì làm log trước, chốt mục tiêu sau."))
        #expect(text.contains("**Điều kiện lật:** Log năm ngày không ra tín hiệu nào."))
        #expect(text.contains("**Follow-up:** 2026-09-05"))
        // What the first turn settled is still there, above the update.
        #expect(text.contains(caseFixture.direction))
        #expect(try repo.memoryText() == indexAfterFirstTurn)
        #expect(repo.caseFileNames == ["2026-08-15-tri-hoan-viec-nho.md"])
    }

    @Test("Lượt sau không có gì mới để ghi thì file ca giữ nguyên")
    func anEmptyUpdateChangesNothing() throws {
        let repo = try TempRepo(prefix: "case-resume-empty")
        let filed = try repo.caseStore.create(caseFixture, date: TempRepo.noon(august: 15))
        let before = try repo.fileText(at: filed.relativePath)

        try repo.caseStore.appendUpdate(CaseSummary(problem: "Vẫn chuyện cũ."), toCaseAt: filed.relativePath,
                                        date: TempRepo.noon(august: 16))

        #expect(try repo.fileText(at: filed.relativePath) == before)
    }

    /// The consult remembers a file the reader deleted: say so rather than
    /// quietly opening a second case for the same conversation.
    @Test("File ca bị xoá giữa chừng → lỗi nói rõ, không lặng lẽ tạo file mới")
    func appendingToAMissingCaseFileFails() throws {
        let repo = try TempRepo(prefix: "case-resume-missing")

        #expect(throws: CaseFileStoreError.self) {
            try repo.caseStore.appendUpdate(
                CaseSummary(direction: "Làm A trước."),
                toCaseAt: "memory/cases/2026-08-15-khong-co.md",
                date: TempRepo.noon(august: 16))
        }
        #expect(repo.caseFileNames.isEmpty)
    }
}
