import Foundation

/// Reconciles `--include-partial-messages` with the whole messages that follow it.
///
/// With partials on, the CLI announces a text block (`content_block_start`),
/// streams it as `text_delta`s, and then repeats the finished block as an ordinary
/// `assistant` message. Rendered as they arrive, the answer would appear twice.
///
/// This is the one place that knows the pairing. Everything downstream keeps the
/// vocabulary it already had: a delta becomes a plain `.text` event, and the repeat
/// is swallowed. `SessionViewModel` still just appends `.text` to `streamingText`.
///
/// Counting announced blocks rather than comparing strings: the repeat is identical
/// to the concatenated deltas only when every delta arrived, and a chunk lost to a
/// truncated line must not make the whole message flash up a second time. The
/// terminal `result` is what gets persisted either way, so a partial display never
/// reaches the transcript.
///
/// With the flag off nothing is ever announced and the count stays zero, so whole
/// messages pass straight through — the filter is invisible to a stream that has no
/// partials in it.
struct PartialMessageFilter {
    /// Text blocks announced as streaming whose whole-message repeat is still owed.
    private var pendingStreamedBlocks = 0

    /// The event to forward, or `nil` when this one was bookkeeping.
    mutating func filter(_ event: StreamEvent) -> StreamEvent? {
        switch event {
        case .textBlockStarted:
            pendingStreamedBlocks += 1
            return nil
        case .textDelta(let text, let inSubagent):
            return .text(text, inSubagent: inSubagent)
        case .thinkingDelta(let text, let inSubagent):
            return .thinking(text: text, inSubagent: inSubagent)
        case .text where pendingStreamedBlocks > 0:
            pendingStreamedBlocks -= 1
            return nil
        default:
            return event
        }
    }
}
