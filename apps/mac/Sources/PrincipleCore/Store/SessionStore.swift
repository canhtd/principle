import Foundation
import os

public enum SessionStoreError: Error, Equatable {
    case sessionNotFound(UUID)
}

/// A session file that could not be read, kept so the UI can report it instead
/// of silently losing a conversation.
public struct SkippedSessionFile: Equatable, Sendable {
    public let file: URL
    public let reason: String
}

public struct SessionLoadReport: Sendable {
    public let sessions: [ChatSession]
    public let skipped: [SkippedSessionFile]
}

/// Reads and writes consultations under `<repo>/memory/sessions/` (KTD2).
///
/// One JSON file per session keeps the app and a terminal Claude Code session
/// from stepping on each other, and keeps a corrupt file from taking the whole
/// sidebar down. The repo path is always injected — no hardcoded locations.
public struct SessionStore: Sendable {
    public let repoURL: URL
    private let calendar: Calendar

    private static let logger = Logger(subsystem: PrincipleInfo.bundleIdentifier, category: "SessionStore")

    public init(repoURL: URL, calendar: Calendar = .current) {
        self.repoURL = repoURL
        self.calendar = calendar
    }

    public var sessionsDirectory: URL {
        repoURL
            .appendingPathComponent("memory", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
    }

    public func fileURL(for id: UUID) -> URL {
        sessionsDirectory.appendingPathComponent("\(id.uuidString.lowercased()).json")
    }

    // MARK: - Write

    /// Creates a session and persists it immediately, so a topic typed in the
    /// sheet survives a crash before the first turn.
    @discardableResult
    public func create(
        topic: String,
        model: String,
        createdAt: Date = Date(),
        id: UUID = UUID()
    ) throws -> ChatSession {
        let session = ChatSession(
            id: id,
            topic: topic.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: createdAt,
            model: model
        )
        try save(session)
        return session
    }

    public func save(_ session: ChatSession) throws {
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(session)
        try data.write(to: fileURL(for: session.id), options: .atomic)
    }

    /// Appends one rendered message and, when the turn reported one, records the
    /// engine's session id. Passing `nil` leaves the existing id untouched.
    @discardableResult
    public func appendMessage(
        _ message: ChatMessage,
        to sessionID: UUID,
        claudeSessionID: String? = nil
    ) throws -> ChatSession {
        var session = try load(id: sessionID)
        session.messages.append(message)
        if let claudeSessionID, !claudeSessionID.isEmpty {
            session.claudeSessionID = claudeSessionID
        }
        try save(session)
        return session
    }

    /// Drops an engine session id that the engine no longer recognises (KTD2).
    /// The transcript is kept, so the next turn runs fresh-with-seed.
    @discardableResult
    public func clearClaudeSessionID(for sessionID: UUID) throws -> ChatSession {
        var session = try load(id: sessionID)
        guard session.claudeSessionID != nil else { return session }
        Self.logger.notice("Clearing orphaned engine session id for session \(sessionID.uuidString, privacy: .public)")
        session.claudeSessionID = nil
        try save(session)
        return session
    }

    // MARK: - Read

    public func load(id: UUID) throws -> ChatSession {
        let url = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SessionStoreError.sessionNotFound(id)
        }
        return try Self.decoder.decode(ChatSession.self, from: try Data(contentsOf: url))
    }

    public func loadAll() throws -> [ChatSession] {
        try loadAllWithReport().sessions
    }

    /// Loads every session, skipping unreadable files rather than failing the
    /// whole sidebar (R1). Skipped files are logged and returned.
    public func loadAllWithReport() throws -> SessionLoadReport {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: sessionsDirectory.path) else {
            return SessionLoadReport(sessions: [], skipped: [])
        }
        let files = try fileManager.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )
        .filter { $0.pathExtension.lowercased() == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var sessions: [ChatSession] = []
        var skipped: [SkippedSessionFile] = []
        for file in files {
            do {
                sessions.append(try Self.decoder.decode(ChatSession.self, from: try Data(contentsOf: file)))
            } catch {
                Self.logger.error(
                    "Skipping unreadable session file \(file.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)"
                )
                skipped.append(SkippedSessionFile(file: file, reason: String(describing: error)))
            }
        }
        return SessionLoadReport(sessions: sessions, skipped: skipped)
    }

    // MARK: - Sidebar grouping

    /// Sessions grouped by the day they were created — newest day first, newest
    /// session first within a day (R1).
    public func groupedByDay(_ sessions: [ChatSession]) -> [SessionDayGroup] {
        Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.createdAt) }
            .map { SessionDayGroup(day: $0.key, sessions: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.day > $1.day }
    }

    public func sidebarGroups() throws -> [SessionDayGroup] {
        groupedByDay(try loadAll())
    }

    // MARK: - Coding

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Readable and diff-stable: these files sit next to hand-written notes
        // in memory/ and may be inspected or edited by a terminal session.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
