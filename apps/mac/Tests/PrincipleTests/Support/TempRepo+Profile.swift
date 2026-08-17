import Foundation

@testable import PrincipleCore

/// MEMORY.md fixtures for the throwaway repo. Kept next to the profile tests
/// rather than inside `TempRepo` so the shared helper stays about the two repo
/// markers and nothing else.
extension TempRepo {
    var profile: ProfileStore { ProfileStore(repoURL: root) }

    /// Writes `memory/MEMORY.md` verbatim — no normalising, so a CRLF or
    /// newline-less fixture reaches the store exactly as written.
    func writeMemory(_ text: String) throws {
        let url = profile.fileURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(text.utf8).write(to: url)
    }

    func memoryText() throws -> String {
        try String(contentsOf: profile.fileURL, encoding: .utf8)
    }

    /// The shape of the real repo's file: title, profile, two more sections.
    /// Trimmed down, but the same headings in the same order.
    static let memoryFixture = """
        # MEMORY — đọc file này trước khi chẩn đoán bất kỳ ca nào

        ## Hồ sơ người hỏi

        - **Anh Danny** — PM dẫn một team nhỏ AI-native.
        - Trao đổi bằng tiếng Việt, xưng "anh".

        ## Chủ đề lặp lại

        *(Chưa đủ dữ liệu.)*

        ## Index ca

        - 2026-08-15 · bo-thuoc-la · mở

        """
}
