import Foundation

/// What kind of case this is, in the engine's own words.
///
/// Bước 1 of the ask-ray skill: naming the kind of case is what decides which
/// principles get looked up at all. It arrives in the trailer rather than as a
/// heading in the prose, so the app can draw it where the cards are (KTD3).
public struct Diagnosis: Codable, Equatable, Sendable {
    /// A short name for the kind of case, e.g. "Ca lặp lại — vấn đề cỗ máy".
    public let kind: String
    /// One sentence: why the case was filed under that kind.
    public let why: String

    public init(kind: String, why: String) {
        self.kind = kind
        self.why = why
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Half a diagnosis is still worth drawing; missing both is not.
        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? ""
        why = try container.decodeIfPresent(String.self, forKey: .why) ?? ""
    }

    /// Trimmed, or `nil` when there is nothing to show. The app never fills in
    /// a diagnosis the engine did not make (AE2).
    public var cleaned: Diagnosis? {
        let kind = kind.trimmingCharacters(in: .whitespacesAndNewlines)
        let why = why.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kind.isEmpty || !why.isEmpty else { return nil }
        return Diagnosis(kind: kind, why: why)
    }
}

/// One cited principle: the corpus id, plus the one thing the corpus cannot
/// supply — where this principle cuts into *this* case.
///
/// Title and quote are read from `corpus.jsonl` verbatim, so `apply` is the only
/// model-authored part of a card (AE2). Bước 3 of the skill: the reader can read
/// the principle themselves; the bridge is what they cannot write.
public struct PrincipleRef: Codable, Equatable, Identifiable, Sendable {
    /// Corpus id, e.g. `life:5.6`. Never `num` — "2.1" exists in both parts.
    public let id: String
    /// One or two sentences bridging the principle to the case. Empty when the
    /// engine cited an id without one (the legacy trailer shape).
    public let apply: String

    public init(id: String, apply: String = "") {
        self.id = id
        self.apply = apply
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        apply = try container.decodeIfPresent(String.self, forKey: .apply) ?? ""
    }

    /// The bridge to draw, or `nil` when the engine wrote none.
    public var displayApply: String? {
        let trimmed = apply.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
