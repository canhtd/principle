import Foundation

/// The neighbourhood one principle sits in: every corpus record sharing its
/// `chapter`, in corpus order (R8).
///
/// Matching is on the `chapter` field itself, never on a `num` prefix — the two
/// parts of the book both number from 1, so "5.x" does not identify a chapter
/// (KTD3). Nothing is generated here either: the list is whatever the corpus
/// file says and nothing more (AE2).
public struct ChapterContext: Identifiable, Equatable, Sendable {
    /// The principle the context was opened from.
    public let current: PrincipleRecord
    /// Same-chapter records including `current`, in the order the corpus lists
    /// them. Empty when the record belongs to no chapter.
    public let principles: [PrincipleRecord]

    /// What to show for the handful of records outside any chapter, so the
    /// sheet says why it is empty instead of drawing a blank pane.
    public static let noChapterMessage = "This principle does not sit in any chapter, so there is no chapter context."

    public init(corpus: CorpusStore, record: PrincipleRecord) {
        current = record
        let chapter = record.chapter.trimmingCharacters(in: .whitespacesAndNewlines)
        principles = chapter.isEmpty ? [] : corpus.records.filter { $0.chapter == record.chapter }
    }

    public var id: String { current.id }
    public var chapter: String { current.chapter }
    public var hasContext: Bool { !principles.isEmpty }

    public func isCurrent(_ record: PrincipleRecord) -> Bool { record.id == current.id }
}
