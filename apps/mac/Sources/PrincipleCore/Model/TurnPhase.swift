import Foundation

/// Where a turn currently is, as the UI needs to say it (KTD7, R6).
///
/// A consultation can run for minutes while the engine diagnoses and greps the
/// corpus, so silence is not an option: every phase carries a sentence.
public enum TurnPhase: Equatable, Sendable {
    /// Turn sent, engine has not started reporting work yet.
    case preparing
    /// `thinking` block or `thinking_tokens` heartbeat.
    case thinking
    /// A `tool_use` block; the payload is the line already fit to show.
    case runningTool(String)
    /// Anything with `parent_tool_use_id != null` — a lookup inside a subagent.
    case subagent
    /// Answer text is arriving.
    case answering
    /// Nothing in flight.
    case idle

    /// The progress line, or `nil` when there is nothing to report.
    public var statusLine: String? {
        switch self {
        case .preparing: "Preparing…"
        case .thinking: "Thinking…"
        case .runningTool(let description): description
        case .subagent: "Looking up (subagent)…"
        case .answering: "Answering…"
        case .idle: nil
        }
    }

    public var isStreaming: Bool { self != .idle }
}

/// Turns a `tool_use` block into the sentence shown under the chat.
///
/// The engine describes its own work whenever the tool provides an `input.description`;
/// the fallbacks cover the tools in the corpus recipe, which do not.
public enum ToolProgress {
    public static func describe(_ use: ToolUse) -> String {
        if let description = use.description?.trimmingCharacters(in: .whitespacesAndNewlines),
            !description.isEmpty
        {
            return description
        }
        switch use.name {
        case "Grep", "Glob": return "Searching the corpus…"
        case "Read": return "Reading documents…"
        case "Task": return "Looking up (subagent)…"
        case "Write", "Edit": return "Recording the case…"
        default: return "Running \(use.name)…"
        }
    }
}

/// The two answering models the app offers (KTD8). Subagent tiering is the
/// skill's business, not the app's — whatever is chosen here is passed straight
/// through as `--model`.
public enum ModelAlias {
    public static let fable = "fable"
    public static let opus = "opus"
    public static let `default` = fable

    public static let all = [fable, opus]

    /// The label for the chat header (AE4) and the model picker.
    public static func displayName(_ alias: String) -> String {
        switch alias {
        case fable: "Fable 5"
        case opus: "Opus 5"
        default: alias
        }
    }
}

/// What the new-session sheet collects. Lives here rather than in the view so
/// the "Create" rule (R1: a session always has a topic) is testable.
public struct NewSessionDraft: Equatable, Sendable {
    public var topic: String
    public var model: String

    public init(topic: String = "", model: String = ModelAlias.default) {
        self.topic = topic
        self.model = model
    }

    public var trimmedTopic: String {
        topic.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var canCreate: Bool { !trimmedTopic.isEmpty }
}
