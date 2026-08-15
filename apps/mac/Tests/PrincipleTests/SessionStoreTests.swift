import Foundation
import Testing

@testable import PrincipleCore

/// Every test runs against a throwaway repo in the system temp dir — never the
/// real repo's `memory/`.
private struct TempRepo: ~Copyable {
    let root: URL

    init() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("principle-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    var store: SessionStore { SessionStore(repoURL: root) }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }
}

private func daysAgo(_ days: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: -days, to: Date())!
}

@Suite("SessionStore")
struct SessionStoreTests {
    // MARK: - 1. Create + round-trip

    @Test("Creating a session writes memory/sessions/<uuid>.json and round-trips every field")
    func createRoundTrip() throws {
        let repo = try TempRepo()
        let store = repo.store

        var session = try store.create(topic: "Bỏ thuốc lá", model: "fable")
        let file = repo.root
            .appendingPathComponent("memory/sessions", isDirectory: true)
            .appendingPathComponent("\(session.id.uuidString.lowercased()).json")
        #expect(FileManager.default.fileExists(atPath: file.path))

        // Fill in every remaining field so the round-trip is not vacuous.
        session.claudeSessionID = "engine-abc-123"
        session.messages = [
            ChatMessage(role: .user, text: "Tôi hút một gói mỗi ngày."),
            ChatMessage(role: .assistant, text: "Bắt đầu từ chẩn đoán.", principleIDs: ["life:5.6", "life:1.8"]),
        ]
        try store.save(session)

        let reloaded = try store.load(id: session.id)
        #expect(reloaded.id == session.id)
        #expect(reloaded.topic == "Bỏ thuốc lá")
        #expect(reloaded.model == "fable")
        #expect(reloaded.claudeSessionID == "engine-abc-123")
        #expect(reloaded.messages.count == 2)
        #expect(reloaded.messages[0].role == .user)
        #expect(reloaded.messages[0].text == "Tôi hút một gói mỗi ngày.")
        #expect(reloaded.messages[1].role == .assistant)
        #expect(reloaded.messages[1].principleIDs == ["life:5.6", "life:1.8"])
        // Dates survive the JSON hop at second resolution.
        #expect(abs(reloaded.createdAt.timeIntervalSince(session.createdAt)) < 1)
        #expect(abs(reloaded.messages[0].sentAt.timeIntervalSince(session.messages[0].sentAt)) < 1)

        // KTD2 names the persisted key `claude_session_id`.
        let raw = try String(contentsOf: file, encoding: .utf8)
        #expect(raw.contains("\"claude_session_id\""))
    }

    @Test("The sessions directory is created on demand")
    func createsDirectoryWhenMissing() throws {
        let repo = try TempRepo()
        let dir = repo.root.appendingPathComponent("memory/sessions", isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: dir.path))

        _ = try repo.store.create(topic: "Ca đầu tiên", model: "fable")
        #expect(FileManager.default.fileExists(atPath: dir.path))
    }

    // MARK: - 2. Sidebar grouping

    @Test("Two sessions today plus one yesterday group into 2 days, newest first")
    func groupsByDayNewestFirst() throws {
        let repo = try TempRepo()
        let store = repo.store

        let older = try store.create(topic: "Hôm nay sớm", model: "fable", createdAt: Date().addingTimeInterval(-3600))
        let newer = try store.create(topic: "Hôm nay muộn", model: "fable", createdAt: Date())
        let yesterday = try store.create(topic: "Hôm qua", model: "opus", createdAt: daysAgo(1))

        let groups = try store.sidebarGroups()
        #expect(groups.count == 2)
        #expect(groups[0].sessions.map(\.id) == [newer.id, older.id])
        #expect(groups[1].sessions.map(\.id) == [yesterday.id])
        #expect(groups[0].day > groups[1].day)
        #expect(Calendar.current.isDateInToday(groups[0].day))
    }

    // MARK: - 3. Corrupt files (R1)

    @Test("A corrupt session file is skipped and reported; the rest still load")
    func corruptFileIsSkipped() throws {
        let repo = try TempRepo()
        let store = repo.store

        let good1 = try store.create(topic: "Ca lành 1", model: "fable")
        let good2 = try store.create(topic: "Ca lành 2", model: "fable")

        let dir = repo.root.appendingPathComponent("memory/sessions", isDirectory: true)
        let broken = dir.appendingPathComponent("broken.json")
        try Data("{ this is not json".utf8).write(to: broken)
        // Stray non-JSON files must not count as problems either.
        try Data("noise".utf8).write(to: dir.appendingPathComponent(".DS_Store"))

        let report = try store.loadAllWithReport()
        #expect(Set(report.sessions.map(\.id)) == Set([good1.id, good2.id]))
        #expect(report.skipped.map { $0.file.lastPathComponent } == ["broken.json"])

        // The convenience path behaves the same, minus the diagnostics.
        #expect(try store.loadAll().count == 2)
        // Grouping tolerates the corrupt file too.
        #expect(try store.sidebarGroups().flatMap(\.sessions).count == 2)
    }

    @Test("Loading from a repo with no sessions directory yields an empty list")
    func loadsEmptyWhenDirectoryMissing() throws {
        let repo = try TempRepo()
        #expect(try repo.store.loadAll().isEmpty)
        #expect(try repo.store.sidebarGroups().isEmpty)
    }

    // MARK: - 4. Resume id (F2 / AE1 at store level)

    @Test("Opening a session that has a claude_session_id offers it as the resume id")
    func openSessionOffersResumeID() throws {
        let repo = try TempRepo()
        let store = repo.store

        let created = try store.create(topic: "Ca cũ", model: "fable")
        #expect(created.nextTurnStart == .fresh)

        let afterTurn = try store.appendMessage(
            ChatMessage(role: .assistant, text: "Định hướng lượt một."),
            to: created.id,
            claudeSessionID: "engine-session-42"
        )
        #expect(afterTurn.claudeSessionID == "engine-session-42")

        let reopened = try store.load(id: created.id)
        #expect(reopened.claudeSessionID == "engine-session-42")
        #expect(reopened.nextTurnStart == .resume(claudeSessionID: "engine-session-42"))
    }

    @Test("appendMessage keeps the existing resume id when the turn does not report a new one")
    func appendKeepsResumeIDWhenNotReported() throws {
        let repo = try TempRepo()
        let store = repo.store

        let created = try store.create(topic: "Ca cũ", model: "fable")
        _ = try store.appendMessage(
            ChatMessage(role: .user, text: "Lượt một."),
            to: created.id,
            claudeSessionID: "engine-session-42"
        )
        let after = try store.appendMessage(ChatMessage(role: .user, text: "Lượt hai."), to: created.id)
        #expect(after.claudeSessionID == "engine-session-42")
        #expect(after.messages.map(\.text) == ["Lượt một.", "Lượt hai."])
    }

    @Test("Appending to an unknown session id throws instead of creating a stray file")
    func appendToUnknownSessionThrows() throws {
        let repo = try TempRepo()
        let store = repo.store
        let ghost = UUID()
        #expect(throws: SessionStoreError.sessionNotFound(ghost)) {
            _ = try store.appendMessage(ChatMessage(role: .user, text: "Xin chào"), to: ghost)
        }
    }

    // MARK: - 5. Orphaned resume id (KTD2)

    @Test("Clearing an orphaned resume id keeps the transcript and starts the next turn fresh-with-seed")
    func clearOrphanedResumeID() throws {
        let repo = try TempRepo()
        let store = repo.store

        let created = try store.create(topic: "Ca mồ côi", model: "fable")
        _ = try store.appendMessage(
            ChatMessage(role: .user, text: "Tôi nên làm gì?"),
            to: created.id,
            claudeSessionID: "engine-gone"
        )
        _ = try store.appendMessage(
            ChatMessage(role: .assistant, text: "Chẩn đoán trước đã.", principleIDs: ["life:5.6"]),
            to: created.id
        )

        // Engine context vanished (~/.claude pruned): drop the dead id.
        let cleared = try store.clearClaudeSessionID(for: created.id)
        #expect(cleared.claudeSessionID == nil)

        // The session still opens, transcript intact, and the next turn re-seeds.
        let reopened = try store.load(id: created.id)
        #expect(reopened.claudeSessionID == nil)
        #expect(reopened.messages.map(\.text) == ["Tôi nên làm gì?", "Chẩn đoán trước đã."])
        #expect(reopened.messages[1].principleIDs == ["life:5.6"])
        #expect(reopened.nextTurnStart == .freshWithSeed)

        // Clearing again is a no-op, not an error.
        #expect(try store.clearClaudeSessionID(for: created.id).claudeSessionID == nil)

        // After the re-seeded turn the store takes the new engine id.
        let resumed = try store.appendMessage(
            ChatMessage(role: .assistant, text: "Tiếp nối."),
            to: created.id,
            claudeSessionID: "engine-new"
        )
        #expect(resumed.nextTurnStart == .resume(claudeSessionID: "engine-new"))
        #expect(resumed.messages.count == 3)
    }
}
