import Foundation

/// One rendered line of a conversation. The app owns the transcript (KTD2): the
/// engine keeps model context via `--resume`, but everything drawn on screen —
/// and everything used to re-seed a session whose engine context vanished — is
/// persisted here.
public struct ChatMessage: Codable, Identifiable, Equatable, Sendable {
    public enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    public let id: UUID
    public let role: Role
    public let text: String
    public let sentAt: Date
    /// Corpus ids cited by this message (KTD3 trailer). Stored so reopening a
    /// session can re-render its principle cards without calling the engine.
    public let principleIDs: [String]

    public init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        sentAt: Date = Date(),
        principleIDs: [String] = []
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.sentAt = sentAt
        self.principleIDs = principleIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case role
        case text
        case sentAt = "sent_at"
        case principleIDs = "principle_ids"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(Role.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        sentAt = try container.decode(Date.self, forKey: .sentAt)
        // Optional so hand-written or older files stay readable.
        principleIDs = try container.decodeIfPresent([String].self, forKey: .principleIDs) ?? []
    }
}

/// How the next turn of a session must be started.
public enum TurnStart: Equatable, Sendable {
    /// Brand-new session: nothing to resume, nothing to seed.
    case fresh
    /// Engine context is alive — pass this id to `claude --resume`.
    case resume(claudeSessionID: String)
    /// Engine context is gone but the app still owns the transcript: run as a
    /// fresh engine session seeded with the transcript plus the case file.
    case freshWithSeed
}

/// One consultation, persisted as `memory/sessions/<uuid>.json` (KTD2).
public struct ChatSession: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var topic: String
    public let createdAt: Date
    public var model: String
    /// Engine-side context id. Lives outside the repo (`~/.claude`) and can
    /// vanish, so it is optional and clearable.
    public var claudeSessionID: String?
    public var messages: [ChatMessage]

    public init(
        id: UUID = UUID(),
        topic: String,
        createdAt: Date = Date(),
        model: String,
        claudeSessionID: String? = nil,
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.topic = topic
        self.createdAt = createdAt
        self.model = model
        self.claudeSessionID = claudeSessionID
        self.messages = messages
    }

    public var nextTurnStart: TurnStart {
        if let claudeSessionID, !claudeSessionID.isEmpty {
            return .resume(claudeSessionID: claudeSessionID)
        }
        return messages.isEmpty ? .fresh : .freshWithSeed
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case topic
        case createdAt = "created_at"
        case model
        case claudeSessionID = "claude_session_id"
        case messages
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        topic = try container.decode(String.self, forKey: .topic)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        model = try container.decode(String.self, forKey: .model)
        claudeSessionID = try container.decodeIfPresent(String.self, forKey: .claudeSessionID)
        messages = try container.decodeIfPresent([ChatMessage].self, forKey: .messages) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(topic, forKey: .topic)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(model, forKey: .model)
        // Always emit the key, even when nil, so the file shape stays stable.
        try container.encode(claudeSessionID, forKey: .claudeSessionID)
        try container.encode(messages, forKey: .messages)
    }
}

/// One day's worth of sessions for the sidebar.
public struct SessionDayGroup: Identifiable, Equatable, Sendable {
    /// Start of the day the sessions were created in.
    public let day: Date
    public let sessions: [ChatSession]

    public var id: Date { day }

    public init(day: Date, sessions: [ChatSession]) {
        self.day = day
        self.sessions = sessions
    }
}
