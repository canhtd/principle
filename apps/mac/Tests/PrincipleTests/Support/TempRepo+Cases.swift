import Foundation

@testable import PrincipleCore

/// Case-file fixtures for the throwaway repo. The real `memory/cases/` is
/// personal data and no test may touch it.
extension TempRepo {
    /// UTC so a case filed at noon lands on the same day wherever the test runs.
    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    static func noon(august day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: 12)) ?? Date()
    }

    var caseStore: CaseFileStore { CaseFileStore(repoURL: root, calendar: Self.utcCalendar) }

    func writeCaseTemplate(_ text: String) throws {
        let url = caseStore.directoryURL.appendingPathComponent(CaseFileStore.templateFileName)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    func fileText(at relativePath: String) throws -> String {
        let url = relativePath.split(separator: "/").reduce(root) { $0.appendingPathComponent(String($1)) }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Every filed case, template excluded — what a second index line or a
    /// second file would show up in.
    var caseFileNames: [String] {
        let names = try? FileManager.default.contentsOfDirectory(atPath: caseStore.directoryURL.path)
        return (names ?? []).filter { $0 != CaseFileStore.templateFileName }.sorted()
    }

    /// The real template's headings, in the real order.
    static let caseTemplateFixture = """
        # [slug ngắn của ca]

        - **Ngày:** YYYY-MM-DD

        ## Vấn đề (một câu, bằng lời của anh)

        ## Vấn đề thật (nếu khác vấn đề được kể)

        ## Nguyên tắc đã áp

        ## Hướng đã chốt

        ## Cái giá phải trả

        ## Điều kiện lật

        ## Follow-up

        ## Kết quả
        """

    /// `memory/MEMORY.md` as the real repo has it: an index section that already
    /// carries the written-cases sub-heading and one entry.
    static let memoryWithCaseIndex = """
        # MEMORY

        ## Hồ sơ người hỏi

        - **Anh Danny** — PM dẫn một team nhỏ.

        ## Index ca

        Format: `ngày · slug · kiểu ca · hướng đã chốt · trạng thái (mở/đóng)`

        ### Ca đã ghi

        - 2026-08-14 · [ca-cu](cases/2026-08-14-ca-cu.md) · ca cũ · làm việc A trước · mở

        """
}
