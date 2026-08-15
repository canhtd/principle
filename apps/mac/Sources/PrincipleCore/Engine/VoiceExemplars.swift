import Foundation

/// A few paragraphs of the book's own prose, handed to the engine as the cadence
/// to write in.
///
/// Describing the voice turned out not to be enough. With the rules alone a real
/// answer came back in slogans ("Phải đo.", "Chờ log nói."), opened on a clever
/// reversal, ran em-dashes through every sentence and cited no principle number
/// at all — a productivity coach, not the Vietnamese edition. Showing the model
/// four paragraphs of the translation says what a rule cannot.
///
/// Only the ids live in this file. The corpus is gitignored because the
/// translation is copyrighted, so the text is read off the reader's own disk at
/// runtime; a checkout without the corpus simply gets no exemplars, and the
/// prompt looks exactly as it did before this existed.
public struct VoiceExemplars: Sendable, Equatable {
    /// One passage, ready to quote.
    public struct Passage: Sendable, Equatable {
        /// The number as the book prints it, e.g. `1.6`.
        public let num: String
        /// Which half of the book it comes from. Both parts number from 1, so
        /// the number alone would not say where the passage is (KTD3).
        public let part: String
        /// The opening of the body, verbatim, cut on a word boundary.
        public let text: String

        public init(num: String, part: String, text: String) {
            self.num = num
            self.part = part
            self.text = text
        }
    }

    /// The passages that carry the voice, in the order they are shown.
    ///
    /// Picked by reading the bodies rather than by guessing at ids: each one
    /// explains a mechanism in the first person before it prescribes anything,
    /// which is precisely the move the app's answers were missing.
    ///
    /// - `life:1.6` — "Tôi thấy rằng…", a whole arc of learning from nature.
    /// - `life:1.10g` — first person about his own mistakes, not a slogan in it.
    /// - `life:2.3b` — proximate versus root cause, with a plain example.
    /// - `work:3.3c` — second- and third-order consequences, worked through.
    public static let ids = ["life:1.6", "life:1.10g", "life:2.3b", "work:3.3c"]

    /// Long enough to show a paragraph's shape, short enough that four of them
    /// stay a sample rather than a second prompt.
    static let wordLimit = 120
    /// Under this a body is a caption, not a paragraph — quoting one would teach
    /// back the staccato this exists to remove.
    static let minimumWords = 40
    /// The ceiling over all passages together.
    static let totalWordCap = 500

    public var passages: [Passage]

    /// No corpus on disk, or nothing in it long enough to quote.
    public static let empty = VoiceExemplars(passages: [])

    public init(passages: [Passage]) {
        self.passages = passages
    }

    /// Picks the exemplars out of a corpus already in memory — the app loads one
    /// per repo anyway, so this costs no extra read.
    ///
    /// An id the corpus does not know, a heading-only record (AE3) and a body too
    /// short are all skipped in silence: a missing exemplar makes the prompt
    /// weaker, never broken.
    public init(corpus: CorpusStore) {
        var spent = 0
        passages = Self.ids.compactMap { id in
            guard let record = corpus.principle(id: id), let body = record.displayBody else { return nil }
            let words = body.split(whereSeparator: \.isWhitespace)
            guard words.count >= Self.minimumWords else { return nil }
            let taken = min(words.count, Self.wordLimit)
            guard spent + taken <= Self.totalWordCap else { return nil }
            spent += taken
            let text = words.prefix(taken).joined(separator: " ")
            return Passage(num: record.num, part: record.part, text: taken < words.count ? text + "…" : text)
        }
    }

    public init(repoURL: URL) {
        self.init(corpus: CorpusStore(repoURL: repoURL))
    }

    /// The phrase the static system prompt points the engine at. Its own
    /// constant so the two cannot drift; ``header`` opens with it.
    public static let headerTitle = "Giọng của tôi trong sách"

    /// What the passages are introduced with.
    ///
    /// Its own constant, spelled without interpolation: `Tests/E2E/e2e-smoke.sh`
    /// reads this literal straight out of the source so a real-engine run is
    /// given the same header the app gives it, and an interpolation would reach
    /// the engine as the literal text `\(...)`.
    public static let header = """
        Giọng của tôi trong sách — viết như thế này. Bám nhịp câu, cách giải thích
        cơ chế rồi mới kết luận, và độ dài đoạn của mấy đoạn dưới đây; đừng chép lại
        nội dung của chúng nếu ca đang hỏi không dính tới:
        """

    /// The block spliced into the system prompt, empty when nothing was read.
    public var promptSection: String {
        guard !passages.isEmpty else { return "" }
        let quoted = passages.map { passage in
            let origin = passage.part.isEmpty ? "" : ", phần \(passage.part)"
            return "\"\(passage.text)\"\n(nguyên tắc \(passage.num)\(origin))"
        }
        return "\(Self.header)\n\n\(quoted.joined(separator: "\n\n"))"
    }
}
