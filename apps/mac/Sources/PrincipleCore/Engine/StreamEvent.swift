import Foundation

/// One meaningful thing the engine told us, decoded from a single `stream-json`
/// line. A line may carry several events (an `assistant` message holds a list of
/// content blocks), and many lines carry none at all (hooks, rate-limit notices).
public enum StreamEvent: Sendable, Equatable {
    /// `system` / `init` — the engine accepted the turn and announced its manifest.
    case sessionStarted(SessionInit)
    /// An `assistant` `thinking` block.
    case thinking(text: String, inSubagent: Bool)
    /// An `assistant` `tool_use` block.
    case toolUse(ToolUse)
    /// A `user` `tool_result` block — the engine feeding a tool's output back to itself.
    case toolResult(ToolResult)
    /// An `assistant` `text` block: the answer the user reads.
    case text(String, inSubagent: Bool)
    /// `system` / `thinking_tokens` — a running estimate, useful only as a heartbeat.
    case thinkingTokens(estimated: Int)
    /// Terminal event. Nothing follows it.
    case result(RunResult)

    /// True when the event happened inside a subagent (`parent_tool_use_id != null`),
    /// which the UI shows as "Looking up (subagent)…" rather than as the answer.
    public var isInSubagent: Bool {
        switch self {
        case .thinking(_, let inSubagent), .text(_, let inSubagent): inSubagent
        case .toolUse(let use): use.isInSubagent
        case .toolResult(let result): result.isInSubagent
        case .sessionStarted, .thinkingTokens, .result: false
        }
    }

    /// The manifest, when this is the opening event.
    public var sessionStarted: SessionInit? {
        if case .sessionStarted(let start) = self { return start }
        return nil
    }

    /// The terminal payload, when this is the closing event.
    public var runResult: RunResult? {
        if case .result(let result) = self { return result }
        return nil
    }
}

/// Payload of `system` / `init`.
public struct SessionInit: Sendable, Equatable {
    /// The id to pass to `--resume` on the next turn.
    public let sessionID: String
    public let model: String?
    public let cwd: String?
    public let tools: [String]
    /// Skills the engine loaded — this is how we confirm `ask-ray` is in play.
    public let skills: [String]

    public init(sessionID: String, model: String?, cwd: String?, tools: [String], skills: [String]) {
        self.sessionID = sessionID
        self.model = model
        self.cwd = cwd
        self.tools = tools
        self.skills = skills
    }
}

/// Payload of an `assistant` `tool_use` block.
public struct ToolUse: Sendable, Equatable {
    public let id: String
    public let name: String
    /// `input.description` when the tool provides one — the progress line the UI shows.
    /// Absent for tools that do not describe themselves (e.g. `Read`).
    public let description: String?
    public let isInSubagent: Bool

    public init(id: String, name: String, description: String?, isInSubagent: Bool) {
        self.id = id
        self.name = name
        self.description = description
        self.isInSubagent = isInSubagent
    }
}

/// Payload of a `user` `tool_result` block.
public struct ToolResult: Sendable, Equatable {
    public let toolUseID: String
    /// Flattened text of the result; `nil` when the payload is not textual.
    public let text: String?
    public let isError: Bool
    public let isInSubagent: Bool

    public init(toolUseID: String, text: String?, isError: Bool, isInSubagent: Bool) {
        self.toolUseID = toolUseID
        self.text = text
        self.isError = isError
        self.isInSubagent = isInSubagent
    }
}

/// Payload of the terminal `result` event.
public struct RunResult: Sendable, Equatable {
    /// Persisted by SessionStore so the next turn can `--resume`.
    public let sessionID: String
    public let isError: Bool
    /// The final answer, or the failure message when `isError`.
    public let text: String
    /// e.g. `success`, `error_during_execution`.
    public let subtype: String?

    public init(sessionID: String, isError: Bool, text: String, subtype: String?) {
        self.sessionID = sessionID
        self.isError = isError
        self.text = text
        self.subtype = subtype
    }
}
