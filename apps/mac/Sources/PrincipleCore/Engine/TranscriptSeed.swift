import Foundation

/// Rebuilds a lost engine context out of the transcript the app owns (KTD2).
///
/// The engine's own context lives in `~/.claude` and can disappear — pruned,
/// deleted, or left behind when the repo moves. When it does, the next turn runs
/// as a brand-new engine session with this block in front of the question, so
/// the conversation continues instead of starting from zero.
public enum TranscriptSeed {
    public static let header = "[Ngữ cảnh phiên — app cấp lại vì ngữ cảnh engine đã mất]"
    public static let footer = "[Hết ngữ cảnh]"

    /// Keeps the seed compact: the last few exchanges, each truncated. A full
    /// transcript would cost more than the context it restores.
    public static func prompt(
        for session: ChatSession,
        question: String,
        maxMessages: Int = 12,
        maxCharacters: Int = 600
    ) -> String {
        let history = messagesForSeed(session.messages, question: question)
        guard !history.isEmpty else { return question }

        var lines = [header, "Chủ đề: \(session.topic)"]
        lines += history.suffix(maxMessages).map { message in
            let speaker = message.role == .user ? "Người hỏi" : "Ray"
            return "\(speaker): \(truncate(message.text, to: maxCharacters))"
        }
        lines.append(footer)
        return lines.joined(separator: "\n") + "\n\n" + question
    }

    /// The question was already appended to the transcript before the turn ran,
    /// so it would otherwise appear twice — once as history, once as the ask.
    private static func messagesForSeed(_ messages: [ChatMessage], question: String) -> [ChatMessage] {
        var history = messages
        while let last = history.last, last.role == .user, last.text == question {
            history.removeLast()
        }
        return history
    }

    private static func truncate(_ text: String, to limit: Int) -> String {
        let collapsed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > limit else { return collapsed }
        return String(collapsed.prefix(limit)) + "…"
    }
}
