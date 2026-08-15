import Foundation
import Testing

@testable import PrincipleCore

/// Every test writes into a throwaway repo under the system temp dir; the real
/// repo's `memory/` is never touched.
private final class TempRepoDir {
    let root: URL

    init() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("principle-fav-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    var store: FavoritesStore { FavoritesStore(repoURL: root) }

    deinit { try? FileManager.default.removeItem(at: root) }
}

private func lines(of store: FavoritesStore) throws -> [String] {
    let text = try String(contentsOf: store.fileURL, encoding: .utf8)
    return text.split(separator: "\n").map(String.init)
}

private func keys(of line: String) throws -> Set<String> {
    let object = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
    return Set(try #require(object).keys)
}

private func fixtureCorpus() throws -> CorpusStore {
    CorpusStore(fileURL: try #require(Bundle.module.url(forResource: "Fixtures/corpus-sample", withExtension: "jsonl")))
}

@Suite("FavoritesStore")
struct FavoritesStoreTests {
    // MARK: - 1. Append-only schema and replay (R7, KTD6)

    @Test("Thích → một dòng đúng schema id + saved_at, không có key thừa")
    func favoriteAppendsOneLineWithTheKTDSchema() throws {
        let repo = try TempRepoDir()
        let store = repo.store
        #expect(store.fileURL.path.hasSuffix("memory/favorites.jsonl"))

        try store.favorite(id: "life:5.6", at: Date(timeIntervalSince1970: 1_770_000_000))

        let written = try lines(of: store)
        #expect(written.count == 1)
        #expect(try keys(of: written[0]) == ["id", "saved_at"])
        #expect(written[0].contains("\"id\":\"life:5.6\""))
        #expect(store.favoriteIDs() == ["life:5.6"])
    }

    @Test("Bỏ thích → dòng removed nối thêm, dòng cũ vẫn còn nguyên")
    func unfavoriteAppendsARemovedLineWithoutRewriting() throws {
        let repo = try TempRepoDir()
        let store = repo.store

        try store.favorite(id: "life:5.6")
        try store.unfavorite(id: "life:5.6")

        let written = try lines(of: store)
        #expect(written.count == 2)
        #expect(try keys(of: written[0]) == ["id", "saved_at"])
        #expect(try keys(of: written[1]) == ["id", "removed", "saved_at"])
        #expect(written[1].contains("\"removed\":true"))
        #expect(store.favoriteIDs().isEmpty)
    }

    @Test("Replay theo thứ tự file: dòng cuối của mỗi id thắng")
    func replayLetsTheLastLinePerIDWin() throws {
        let repo = try TempRepoDir()
        let store = repo.store

        try store.favorite(id: "life:5.6")
        try store.favorite(id: "life:1.8")
        try store.unfavorite(id: "life:5.6")
        #expect(store.favoriteIDs() == ["life:1.8"])

        // Thích lại → id quay lại, đứng cuối vì đó là hành động mới nhất.
        try store.favorite(id: "life:5.6")
        #expect(store.favoriteIDs() == ["life:1.8", "life:5.6"])
        #expect(try lines(of: store).count == 4)
    }

    @Test("Bỏ thích id chưa từng thích → không crash, trạng thái vẫn rỗng")
    func unfavoriteOfAnUnsavedIDIsHarmless() throws {
        let repo = try TempRepoDir()
        let store = repo.store

        try store.unfavorite(id: "life:999.9")
        #expect(store.favoriteIDs().isEmpty)
    }

    @Test("Chưa có file favorites → đọc ra rỗng, không crash")
    func missingFileReadsEmpty() throws {
        let repo = try TempRepoDir()
        #expect(repo.store.entries().isEmpty)
        #expect(repo.store.favoriteIDs().isEmpty)
    }

    // MARK: - 2. A corrupt line must not cost the rest of the file

    @Test("Dòng hỏng xen giữa → bỏ qua dòng đó, các dòng còn lại vẫn replay đúng")
    func aCorruptLineIsSkippedAndTheRestStillReplays() throws {
        let repo = try TempRepoDir()
        let store = repo.store
        try FileManager.default.createDirectory(
            at: store.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(
            """
            {"id":"life:1.8","saved_at":"2026-08-14T01:00:00Z"}
            {"id":"life:5.6","saved_at":
            khong-phai-json

            {"saved_at":"2026-08-14T01:02:00Z"}
            {"id":"work:2.1","saved_at":"2026-08-14T01:03:00Z"}
            {"id":"life:1.8","removed":true,"saved_at":"2026-08-14T01:04:00Z"}
            """.utf8
        ).write(to: store.fileURL)

        // Dòng cụt, dòng rác, dòng trống và dòng thiếu id đều bị bỏ.
        #expect(store.entries().map(\.id) == ["life:1.8", "work:2.1", "life:1.8"])
        #expect(store.favoriteIDs() == ["work:2.1"])

        // Ghi tiếp vẫn nối vào cuối, không sửa lại các dòng cũ.
        try store.favorite(id: "life:5.6")
        #expect(store.favoriteIDs() == ["work:2.1", "life:5.6"])
    }

    @Test("File cũ thiếu newline cuối → dòng mới không dính vào dòng cũ")
    func appendAddsTheMissingNewlineFirst() throws {
        let repo = try TempRepoDir()
        let store = repo.store
        try FileManager.default.createDirectory(
            at: store.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{"id":"life:1.8","saved_at":"2026-08-14T01:00:00Z"}"#.utf8).write(to: store.fileURL)

        try store.favorite(id: "life:5.6")

        #expect(try lines(of: store).count == 2)
        #expect(store.favoriteIDs() == ["life:1.8", "life:5.6"])
    }
}
