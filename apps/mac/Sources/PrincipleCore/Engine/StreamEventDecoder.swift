import Foundation

/// Turns one line of `claude -p --output-format stream-json --verbose` into events.
///
/// The stream is a moving target: the CLI already emits `system/hook_started`,
/// `system/hook_response` and `rate_limit_event` lines this app has no use for, and
/// will emit more kinds over time. So the rule is *recognise, never validate*: any
/// line we do not understand — unknown type, unknown block, malformed JSON, missing
/// required field — yields no events instead of an error. A new CLI release must
/// never be able to crash the app or abort a session mid-answer.
///
/// Free functions over `JSONSerialization` rather than `Codable`: the payload is
/// heterogeneous and half-optional, and a `Decodable` graph would fail the whole
/// line on a field we never asked about.
public enum StreamEventDecoder {
    public static func events(fromLine line: String) -> [StreamEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
            let data = trimmed.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data),
            let root = object as? [String: Any],
            let type = root["type"] as? String
        else { return [] }

        // A JSON `null` bridges to NSNull, so the cast fails and the flag stays false.
        let inSubagent = (root["parent_tool_use_id"] as? String)?.isEmpty == false

        switch type {
        case "system": return systemEvents(root)
        case "assistant": return assistantEvents(root, inSubagent: inSubagent)
        case "user": return userEvents(root, inSubagent: inSubagent)
        case "stream_event": return partialEvents(root, inSubagent: inSubagent)
        case "result": return resultEvents(root)
        default: return []
        }
    }

    /// `--include-partial-messages` chunks: the raw API events, forwarded one per
    /// line while a message is still being generated.
    ///
    /// Only the three shapes that move the UI are recognised. `message_start`,
    /// `message_delta`, `content_block_stop`, `signature_delta` and
    /// `input_json_delta` are all real events this app has nothing to do with —
    /// the finished `assistant` message says everything they would have.
    private static func partialEvents(_ root: [String: Any], inSubagent: Bool) -> [StreamEvent] {
        guard let event = root["event"] as? [String: Any] else { return [] }
        switch event["type"] as? String {
        case "content_block_start":
            let block = event["content_block"] as? [String: Any]
            guard block?["type"] as? String == "text" else { return [] }
            return [.textBlockStarted(inSubagent: inSubagent)]
        case "content_block_delta":
            guard let delta = event["delta"] as? [String: Any] else { return [] }
            switch delta["type"] as? String {
            case "text_delta":
                guard let text = delta["text"] as? String, !text.isEmpty else { return [] }
                return [.textDelta(text, inSubagent: inSubagent)]
            case "thinking_delta":
                guard let text = delta["thinking"] as? String, !text.isEmpty else { return [] }
                return [.thinkingDelta(text: text, inSubagent: inSubagent)]
            default:
                return []
            }
        default:
            return []
        }
    }

    private static func systemEvents(_ root: [String: Any]) -> [StreamEvent] {
        switch root["subtype"] as? String {
        case "init":
            guard let sessionID = root["session_id"] as? String else { return [] }
            return [
                .sessionStarted(
                    SessionInit(
                        sessionID: sessionID,
                        model: root["model"] as? String,
                        cwd: root["cwd"] as? String,
                        tools: stringList(root["tools"]),
                        skills: stringList(root["skills"])
                    ))
            ]
        case "thinking_tokens":
            guard let estimated = root["estimated_tokens"] as? Int else { return [] }
            return [.thinkingTokens(estimated: estimated)]
        default:
            return []
        }
    }

    private static func assistantEvents(_ root: [String: Any], inSubagent: Bool) -> [StreamEvent] {
        contentBlocks(root).compactMap { block in
            switch block["type"] as? String {
            case "thinking":
                guard let text = block["thinking"] as? String else { return nil }
                return .thinking(text: text, inSubagent: inSubagent)
            case "text":
                guard let text = block["text"] as? String else { return nil }
                return .text(text, inSubagent: inSubagent)
            case "tool_use":
                guard let id = block["id"] as? String, let name = block["name"] as? String else { return nil }
                let input = block["input"] as? [String: Any]
                return .toolUse(
                    ToolUse(
                        id: id,
                        name: name,
                        description: input?["description"] as? String,
                        isInSubagent: inSubagent
                    ))
            default:
                return nil
            }
        }
    }

    private static func userEvents(_ root: [String: Any], inSubagent: Bool) -> [StreamEvent] {
        contentBlocks(root).compactMap { block in
            guard block["type"] as? String == "tool_result",
                let toolUseID = block["tool_use_id"] as? String
            else { return nil }
            return .toolResult(
                ToolResult(
                    toolUseID: toolUseID,
                    text: flattenedText(block["content"]),
                    isError: block["is_error"] as? Bool ?? false,
                    isInSubagent: inSubagent
                ))
        }
    }

    private static func resultEvents(_ root: [String: Any]) -> [StreamEvent] {
        guard let sessionID = root["session_id"] as? String else { return [] }
        return [
            .result(
                RunResult(
                    sessionID: sessionID,
                    isError: root["is_error"] as? Bool ?? false,
                    text: root["result"] as? String ?? "",
                    subtype: root["subtype"] as? String
                ))
        ]
    }

    private static func contentBlocks(_ root: [String: Any]) -> [[String: Any]] {
        guard let message = root["message"] as? [String: Any] else { return [] }
        return message["content"] as? [[String: Any]] ?? []
    }

    /// `tool_result.content` is either a plain string or a list of content blocks.
    private static func flattenedText(_ content: Any?) -> String? {
        if let text = content as? String { return text }
        guard let blocks = content as? [[String: Any]] else { return nil }
        let parts = blocks.compactMap { $0["text"] as? String }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    private static func stringList(_ value: Any?) -> [String] {
        (value as? [Any])?.compactMap { $0 as? String } ?? []
    }
}
