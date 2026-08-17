import Foundation
import Testing

@testable import PrincipleCore

/// The line order here is the real one, taken from a capture: the CLI emits the
/// finished `assistant` message *before* the block's `content_block_stop`, so the
/// filter cannot wait for the stop to know a repeat is coming.
@Suite("partial message filter")
struct PartialMessageFilterTests {
    private func run(_ events: [StreamEvent]) -> [StreamEvent] {
        var filter = PartialMessageFilter()
        return events.compactMap { filter.filter($0) }
    }

    @Test("Deltas become text; the whole-message repeat is dropped")
    func deltasReplaceTheWholeMessage() {
        let out = run([
            .textBlockStarted(inSubagent: false),
            .textDelta("Hãy ", inSubagent: false),
            .textDelta("chẩn đoán trước.", inSubagent: false),
            .text("Hãy chẩn đoán trước.", inSubagent: false),
        ])

        #expect(out.compactMap(\.assistantText) == ["Hãy ", "chẩn đoán trước."])
        #expect(out.count == 2)
    }

    @Test("Each announced block cancels exactly one repeat")
    func blocksAreCountedOneForOne() {
        let out = run([
            .textBlockStarted(inSubagent: false),
            .textDelta("một", inSubagent: false),
            .text("một", inSubagent: false),
            .textBlockStarted(inSubagent: false),
            .textDelta("hai", inSubagent: false),
            .text("hai", inSubagent: false),
        ])

        #expect(out.compactMap(\.assistantText) == ["một", "hai"])
    }

    /// The flag off, or a CLI that stops sending partials: whole messages are the
    /// only text there is, and every one of them has to reach the screen.
    @Test("A stream with no partials in it passes through untouched")
    func wholeMessagesSurviveWithoutPartials() {
        let events: [StreamEvent] = [
            .sessionStarted(SessionInit(sessionID: "s", model: nil, cwd: nil, tools: [], skills: [])),
            .thinking(text: "ngẫm", inSubagent: false),
            .toolUse(ToolUse(id: "t1", name: "Grep", description: nil, isInSubagent: false)),
            .text("cả câu trả lời", inSubagent: false),
            .result(RunResult(sessionID: "s", isError: false, text: "cả câu trả lời", subtype: "success")),
        ]

        #expect(run(events) == events)
    }

    /// A repeat is only ever owed for a block that was announced. An unannounced
    /// message — a resume turn the CLI decided not to stream, say — must not be
    /// swallowed by a count left over from an earlier one.
    @Test("An unmatched whole message is kept")
    func unannouncedTextIsKept() {
        let out = run([
            .textBlockStarted(inSubagent: false),
            .textDelta("một", inSubagent: false),
            .text("một", inSubagent: false),
            .text("hai", inSubagent: false),
        ])

        #expect(out.compactMap(\.assistantText) == ["một", "hai"])
    }

    @Test("Thinking deltas arrive as thinking, keeping the progress line alive")
    func thinkingDeltasBecomeThinking() {
        let out = run([.thinkingDelta(text: "đang ngẫm", inSubagent: false)])

        #expect(out.compactMap(\.thinkingText) == ["đang ngẫm"])
    }

    @Test("The subagent flag rides through the rewrite")
    func subagentFlagSurvives() {
        let out = run([
            .textDelta("tra corpus", inSubagent: true),
            .thinkingDelta(text: "ngẫm", inSubagent: true),
        ])

        #expect(out.map(\.isInSubagent) == [true, true])
    }
}
