import Foundation
import Observation
import os

/// What the ♥ button and the Favorites section share: the saved ids, resolved
/// against the corpus (R7).
///
/// Lives in the library rather than next to the views so the whole loop —
/// toggle → appended line → replayed state — is testable against a temp repo.
@MainActor
@Observable
public final class FavoritesModel {
    /// Saved ids, newest save first — the order the list reads in.
    public private(set) var ids: [String] = []
    public private(set) var errorMessage: String?

    private var active: Set<String> = []
    private let store: FavoritesStore
    /// The corpus the ids are resolved against; shared with the chat so the
    /// file is parsed once per launch.
    public let corpus: CorpusStore

    private static let logger = Logger(subsystem: PrincipleInfo.bundleIdentifier, category: "FavoritesModel")

    public static let emptyTitle = "Chưa lưu nguyên tắc nào"
    public static let emptyHint = "Bấm ♥ trên thẻ nguyên tắc trong lúc trò chuyện để giữ nó lại đây."

    public init(store: FavoritesStore, corpus: CorpusStore) {
        self.store = store
        self.corpus = corpus
        refresh()
    }

    public convenience init(repoURL: URL, corpus: CorpusStore? = nil) {
        self.init(store: FavoritesStore(repoURL: repoURL), corpus: corpus ?? CorpusStore(repoURL: repoURL))
    }

    // MARK: - Derived state

    public var isEmpty: Bool { ids.isEmpty }

    /// The cards to draw, newest save first. An id the corpus cannot resolve
    /// produces no card — the app never invents one (AE2).
    public var records: [PrincipleRecord] { corpus.principles(ids: ids) }

    /// Saved ids the corpus does not know: a missing or moved `corpus.jsonl`,
    /// worth saying out loud rather than silently showing a shorter list.
    public var unresolvedIDs: [String] { ids.filter { corpus.principle(id: $0) == nil } }

    public func isFavorite(_ id: String) -> Bool { active.contains(id) }

    // MARK: - Actions

    public func toggle(_ id: String) {
        do {
            if isFavorite(id) {
                try store.unfavorite(id: id)
            } else {
                try store.favorite(id: id)
            }
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = "Không ghi được danh sách yêu thích: \(error.localizedDescription)"
            Self.logger.error("Writing favourites failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Re-reads the file. Called when the section opens too: a terminal session
    /// may have appended lines while the app was on another tab.
    public func refresh() {
        let saved = store.favoriteIDs()
        active = Set(saved)
        ids = saved.reversed()
    }
}
