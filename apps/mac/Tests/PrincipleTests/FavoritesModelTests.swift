import Foundation
import Testing

@testable import PrincipleCore

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
        let repo = try TempRepo(prefix: "favmodel")
        let model = FavoritesModel(store: repo.favorites, corpus: try fixtureCorpus())

        #expect(model.isEmpty)
        #expect(model.records.isEmpty)
        #expect(model.unresolvedIDs.isEmpty)
        #expect(!FavoritesModel.emptyTitle.isEmpty)
        #expect(FavoritesModel.emptyHint.contains("♥"))
        #expect(FavoritesModel.emptyHint.contains("chat"))
    }

    // MARK: - 1. Toggling writes the file the section reads (R7)

    @Test("Bấm ♥ rồi bấm lại → ghi file và trạng thái model khớp nhau")
    func togglingWritesTheFileAndFlipsTheModel() throws {
        let repo = try TempRepo(prefix: "favmodel")
        let model = FavoritesModel(store: repo.favorites, corpus: try fixtureCorpus())

        model.toggle("life:5.6")
        #expect(model.isFavorite("life:5.6"))
        #expect(model.records.map(\.id) == ["life:5.6"])
        #expect(model.errorMessage == nil)

        model.toggle("life:5.6")
        #expect(!model.isFavorite("life:5.6"))
        #expect(model.records.isEmpty)
        #expect(try lineCount(of: repo.favorites) == 2)
    }

    @Test("Danh sách yêu thích xếp mới nhất trước; id corpus không biết thì không dựng thẻ")
    func newestFirstAndUnknownIDsNeverBecomeCards() throws {
        let repo = try TempRepo(prefix: "favmodel")
        try repo.favorites.favorite(id: "life:1.8")
        try repo.favorites.favorite(id: "life:999.9")
        try repo.favorites.favorite(id: "life:5.6")
        let model = FavoritesModel(store: repo.favorites, corpus: try fixtureCorpus())

        #expect(model.ids == ["life:5.6", "life:999.9", "life:1.8"])
        // AE2: an id the corpus does not know is reported, never drawn as a card.
        #expect(model.records.map(\.id) == ["life:5.6", "life:1.8"])
        #expect(model.unresolvedIDs == ["life:999.9"])
    }

    @Test("Session terminal ghi thêm vào file → refresh đọc ra ngay")
    func refreshPicksUpLinesWrittenByAnotherProcess() throws {
        let repo = try TempRepo(prefix: "favmodel")
        let model = FavoritesModel(store: repo.favorites, corpus: try fixtureCorpus())
        #expect(model.isEmpty)

        try repo.favorites.favorite(id: "work:3.4")
        model.refresh()

        #expect(model.isFavorite("work:3.4"))
        #expect(model.records.map(\.id) == ["work:3.4"])
    }
}
