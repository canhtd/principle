import Foundation

/// One rendered line of a conversation. The app owns the transcript (KTD2): the
/// engine keeps model context via `--resume`, but everything drawn on screen —
/// and everything used to re-seed a session whose engine context vanished — is
/// persisted here.
///
/// That includes the whole citation, not just the ids: the diagnosis and the
/// per-principle bridge are model-authored and unreproducible, so reopening a
/// session must not need another turn to draw its cards (KTD3).
public struct ChatMessage: Codable, Identifiable, Equatable, Sendable {
    public enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    public let id: UUID
    public let role: Role
    public let text: String
    public let sentAt: Date
    /// What kind of case the engine filed this answer under, when it said so.
    public let diagnosis: Diagnosis?
    /// The principles this message cited, in citation order.
    public let principles: [PrincipleRef]

    /// Just the cited ids, for the lookups that need nothing else.
    public var principleIDs: [String] { principles.map(\.id) }

    public init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        sentAt: Date = Date(),
        diagnosis: Diagnosis? = nil,
        principles: [PrincipleRef] = []
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.sentAt = sentAt
        self.diagnosis = diagnosis
        self.principles = principles
    }

    /// Ids with no bridge text — the legacy trailer shape.
    public init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        sentAt: Date = Date(),
        principleIDs: [String]
    ) {
        self.init(
            id: id,
            role: role,
            text: text,
            sentAt: sentAt,
            principles: principleIDs.map { PrincipleRef(id: $0) }
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case role
        case text
        case sentAt = "sent_at"
        case diagnosis
        case principles
        /// Read-only: what sessions filed before the rich trailer carry.
        case principleIDs = "principle_ids"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(Role.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        sentAt = try container.decode(Date.self, forKey: .sentAt)
        // All optional so hand-written and older files stay readable.
        diagnosis = try container.decodeIfPresent(Diagnosis.self, forKey: .diagnosis)
        if let cited = try container.decodeIfPresent([PrincipleRef].self, forKey: .principles) {
            principles = cited
        } else {
            principles = (try container.decodeIfPresent([String].self, forKey: .principleIDs) ?? [])
                .map { PrincipleRef(id: $0) }
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(text, forKey: .text)
        try container.encode(sentAt, forKey: .sentAt)
        try container.encodeIfPresent(diagnosis, forKey: .diagnosis)
        try container.encode(principles, forKey: .principles)
    }
}
