import Foundation

/// How the next turn of a session must be started.
public enum TurnStart: Equatable, Sendable {
    /// Brand-new session: nothing to resume, nothing to seed.
    case fresh
    /// Engine context is alive — pass this id to `claude --resume`.
    case resume(claudeSessionID: String)
    /// Engine context is gone but the app still owns the transcript: run as a
    /// fresh engine session seeded with the transcript plus the case file.
    case freshWithSeed

    /// The id to hand `claude --resume`, when there is one.
    public var resumeID: String? {
        guard case .resume(let claudeSessionID) = self else { return nil }
        return claudeSessionID
    }
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
    /// The case file this consult was filed into, relative to the repo root
    /// (`memory/cases/…`). One consult is one case: later turns append to this
    /// file instead of opening a second one. `nil` until the first answer that
    /// carried a `case` in its trailer.
    public var caseFilePath: String?

    public init(
        id: UUID = UUID(),
        topic: String,
        createdAt: Date = Date(),
        model: String,
        claudeSessionID: String? = nil,
        messages: [ChatMessage] = [],
        caseFilePath: String? = nil
    ) {
        self.id = id
        self.topic = topic
        self.createdAt = createdAt
        self.model = model
        self.claudeSessionID = claudeSessionID
        self.messages = messages
        self.caseFilePath = caseFilePath
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
        case caseFilePath = "case_file"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        topic = try container.decode(String.self, forKey: .topic)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        model = try container.decode(String.self, forKey: .model)
        claudeSessionID = try container.decodeIfPresent(String.self, forKey: .claudeSessionID)
        messages = try container.decodeIfPresent([ChatMessage].self, forKey: .messages) ?? []
        // Absent in every session filed before the app owned the case file.
        caseFilePath = try container.decodeIfPresent(String.self, forKey: .caseFilePath)
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
        try container.encode(caseFilePath, forKey: .caseFilePath)
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
