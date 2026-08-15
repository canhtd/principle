import Foundation
import Testing

@testable import PrincipleCore

/// Every test writes into a throwaway repo under the system temp dir; the real
/// repo's `memory/` is never touched.
private final class TempRepoDir {
    let root: URL

    init() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("principle-favmodel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    var store: FavoritesStore { FavoritesStore(repoURL: root) }

    deinit { try? FileManager.default.removeItem(at: root) }
}

private func lineCount(of store: FavoritesStore) throws -> Int {
    try String(contentsOf: store.fileURL, encoding: .utf8).split(separator: "\n").count
}

private func fixtureCorpus() throws -> CorpusStore {
    CorpusStore(fileURL: try #require(Bundle.module.url(forResource: "Fixtures/corpus-sample", withExtension: "jsonl")))
}

@MainActor
@Suite("FavoritesModel")
struct FavoritesModelTests {
    // MARK: - 5. Empty state

    @Test("Chưa có favorite nào → model rỗng và có lời chỉ đường về chat + nút ♥")
    func emptyStatePointsBackToTheChatAndTheHeart() throws {
        let repo = try TempRepoDir()
        let model = FavoritesModel(store: repo.store, corpus: try fixtureCorpus())

        #expect(model.isEmpty)
        #expect(model.records.isEmpty)
        #expect(model.unresolvedIDs.isEmpty)
        #expect(!FavoritesModel.emptyTitle.isEmpty)
        #expect(FavoritesModel.emptyHint.contains("♥"))
        #expect(FavoritesModel.emptyHint.contains("trò chuyện"))
    }

    // MARK: - 1. Toggling writes the file the section reads (R7)

    @Test("Bấm ♥ rồi bấm lại → ghi file và trạng thái model khớp nhau")
    func togglingWritesTheFileAndFlipsTheModel() throws {
        let repo = try TempRepoDir()
        let model = FavoritesModel(store: repo.store, corpus: try fixtureCorpus())

        model.toggle("life:5.6")
        #expect(model.isFavorite("life:5.6"))
        #expect(model.records.map(\.id) == ["life:5.6"])
        #expect(model.errorMessage == nil)

        model.toggle("life:5.6")
        #expect(!model.isFavorite("life:5.6"))
        #expect(model.records.isEmpty)
        #expect(try lineCount(of: repo.store) == 2)
    }

    @Test("Danh sách yêu thích xếp mới nhất trước; id corpus không biết thì không dựng thẻ")
    func newestFirstAndUnknownIDsNeverBecomeCards() throws {
        let repo = try TempRepoDir()
        try repo.store.favorite(id: "life:1.8")
        try repo.store.favorite(id: "life:999.9")
        try repo.store.favorite(id: "life:5.6")
        let model = FavoritesModel(store: repo.store, corpus: try fixtureCorpus())

        #expect(model.ids == ["life:5.6", "life:999.9", "life:1.8"])
        // AE2: an id the corpus does not know is reported, never drawn as a card.
        #expect(model.records.map(\.id) == ["life:5.6", "life:1.8"])
        #expect(model.unresolvedIDs == ["life:999.9"])
    }

    @Test("Session terminal ghi thêm vào file → refresh đọc ra ngay")
    func refreshPicksUpLinesWrittenByAnotherProcess() throws {
        let repo = try TempRepoDir()
        let model = FavoritesModel(store: repo.store, corpus: try fixtureCorpus())
        #expect(model.isEmpty)

        try repo.store.favorite(id: "work:3.4")
        model.refresh()

        #expect(model.isFavorite("work:3.4"))
        #expect(model.records.map(\.id) == ["work:3.4"])
    }
}
