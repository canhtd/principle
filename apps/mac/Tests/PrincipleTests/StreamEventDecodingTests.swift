import Foundation
import Testing

@testable import PrincipleCore

/// The fixture is a real `claude -p --output-format stream-json --verbose` capture
/// (a toy "read note.txt" session), noise lines included: SessionStart hooks and a
/// `rate_limit_event`. Those must be skipped, never crash the decoder.
@Suite("stream-json decoding")
struct StreamEventDecodingTests {
    static let fixture: [StreamEvent] = {
        let url = Bundle.module.url(forResource: "Fixtures/stream-sample", withExtension: "jsonl")
        guard let url, let text = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return text.split(separator: "\n").flatMap { StreamEventDecoder.events(fromLine: String($0)) }
    }()

    static let sessionID = "ccad4235-2fb3-46eb-997c-b234318066fb"

    @Test("Fixture yields every event type and drops the noise lines")
    func fixtureDecodesEveryType() throws {
        let events = Self.fixture
        // 18 lines: 2 hook + 1 rate_limit are dropped, the 4 assistant lines carry
        // one content block each -> 15 events.
        #expect(events.count == 15)

        #expect(events.filter(\.isSessionStarted).count == 1)
        #expect(events.filter(\.isThinking).count == 2)
        #expect(events.filter(\.isToolUse).count == 1)
        #expect(events.filter(\.isToolResult).count == 1)
        #expect(events.filter(\.isText).count == 1)
        #expect(events.filter(\.isThinkingTokens).count == 8)
        #expect(events.filter(\.isResult).count == 1)
    }

    @Test("system/init carries session id, tools and the skills manifest")
    func initIsDecoded() throws {
        let start = try #require(Self.fixture.compactMap(\.sessionStarted).first)
        #expect(start.sessionID == Self.sessionID)
        #expect(start.model == "claude-haiku-4-5-20251001")
        #expect(start.tools.contains("Read"))
        #expect(start.tools.contains("Task"))
        #expect(start.skills.contains("read"))
        #expect(start.cwd?.isEmpty == false)
    }

    @Test("assistant thinking and text blocks keep their text")
    func assistantBlocksAreDecoded() throws {
        let thinking = Self.fixture.compactMap(\.thinkingText)
        #expect(thinking.count == 2)
        #expect(thinking[0].contains("note.txt"))

        let text = try #require(Self.fixture.compactMap(\.assistantText).first)
        #expect(text == "42")
    }

    @Test("tool_use carries name and id; a missing description stays nil")
    func toolUseIsDecoded() throws {
        let use = try #require(Self.fixture.compactMap(\.toolUse).first)
        #expect(use.name == "Read")
        #expect(use.id == "toolu_01GZbCxxMMTtgBgVtbdJNnyn")
        // This capture's Read input has no `description` key.
        #expect(use.description == nil)
        #expect(use.isInSubagent == false)
    }

    @Test("tool_result is matched back to its tool_use id")
    func toolResultIsDecoded() throws {
        let result = try #require(Self.fixture.compactMap(\.toolResult).first)
        #expect(result.toolUseID == "toolu_01GZbCxxMMTtgBgVtbdJNnyn")
        #expect(result.text?.contains("meaning of life is 42") == true)
        #expect(result.isError == false)
    }

    @Test("thinking_tokens carries the running estimate")
    func thinkingTokensAreDecoded() throws {
        let counts = Self.fixture.compactMap(\.thinkingTokens)
        #expect(counts.first == 1)
        #expect(counts.last == 83)
    }

    @Test("result is terminal and carries the session id to resume with")
    func resultIsDecoded() throws {
        let result = try #require(Self.fixture.compactMap(\.runResult).first)
        #expect(result.sessionID == Self.sessionID)
        #expect(result.isError == false)
        #expect(result.text == "42")
        #expect(result.subtype == "success")
        // Terminal event must be the last one decoded.
        #expect(Self.fixture.last?.isResult == true)
    }

    @Test("tool_use description is picked up when the input carries one")
    func toolUseDescriptionIsDecoded() throws {
        let line = """
            {"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_1",\
            "name":"Bash","input":{"command":"grep x","description":"Tra corpus"}}]},\
            "parent_tool_use_id":null,"session_id":"s1"}
            """
        let use = try #require(StreamEventDecoder.events(fromLine: line).compactMap(\.toolUse).first)
        #expect(use.description == "Tra corpus")
    }

    @Test("parent_tool_use_id marks events that happened inside a subagent")
    func subagentEventsAreFlagged() throws {
        let line = """
            {"type":"assistant","message":{"content":[{"type":"text","text":"xong"}]},\
            "parent_tool_use_id":"toolu_parent","session_id":"s1"}
            """
        let events = StreamEventDecoder.events(fromLine: line)
        #expect(events.count == 1)
        #expect(events[0].isInSubagent == true)
    }

    @Test("odd, unknown and malformed lines are skipped without crashing")
    func oddLinesAreSkipped() {
        let lines = [
            "",
            "   ",
            "not json at all",
            "{",
            "[1,2,3]",
            "\"a bare string\"",
            "null",
            "{\"type\":\"system\",\"subtype\":\"hook_started\"}",
            "{\"type\":\"rate_limit_event\",\"rate_limit_info\":{}}",
            "{\"type\":\"future_event_we_have_never_seen\"}",
            "{\"type\":\"assistant\"}",
            "{\"type\":\"assistant\",\"message\":{\"content\":\"a string not an array\"}}",
            "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"weird_block\"}]}}",
            "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\"}]}}",
            "{\"type\":\"system\",\"subtype\":\"init\"}",
            "{\"type\":\"result\"}",
        ]
        for line in lines {
            #expect(StreamEventDecoder.events(fromLine: line).isEmpty, "should skip: \(line)")
        }
    }

    @Test("tool_result content given as blocks is flattened to text")
    func toolResultBlockContentIsFlattened() throws {
        let line = """
            {"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1",\
            "is_error":true,"content":[{"type":"text","text":"khong tim thay file"}]}]},\
            "session_id":"s1"}
            """
        let result = try #require(StreamEventDecoder.events(fromLine: line).compactMap(\.toolResult).first)
        #expect(result.text == "khong tim thay file")
        #expect(result.isError == true)
    }
}

/// Case accessors used only to keep the assertions above readable — the production
/// enum stays lean and callers pattern-match.
extension StreamEvent {
    var isSessionStarted: Bool { sessionStarted != nil }
    var isResult: Bool { runResult != nil }
    var isThinking: Bool { thinkingText != nil }
    var isText: Bool { assistantText != nil }
    var isToolUse: Bool { toolUse != nil }
    var isToolResult: Bool { toolResult != nil }
    var isThinkingTokens: Bool { thinkingTokens != nil }

    var thinkingText: String? {
        if case .thinking(let text, _) = self { return text }
        return nil
    }

    var assistantText: String? {
        if case .text(let text, _) = self { return text }
        return nil
    }

    var toolUse: ToolUse? {
        if case .toolUse(let use) = self { return use }
        return nil
    }

    var toolResult: ToolResult? {
        if case .toolResult(let result) = self { return result }
        return nil
    }

    var thinkingTokens: Int? {
        if case .thinkingTokens(let estimated) = self { return estimated }
        return nil
    }
}
