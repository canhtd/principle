import Foundation

/// Everything the app says to the engine for one consultation turn: the prompt
/// itself, and the system-prompt override that makes the engine answer *this
/// app* instead of a chat window.
///
/// Two jobs the app cannot do anywhere else (KTD3):
///
/// - the answer must end with a machine-readable trailer, because that is how
///   principle cards get drawn without the app re-deciding what was cited;
/// - the ask-ray skill's Bước 4 asks for an artifact, which is the right output
///   in a chat and useless here — so it is cancelled explicitly.
public enum ConsultPrompt {
    /// Passed with `--append-system-prompt` on every turn.
    public static let systemPrompt = """
        Bạn đang trả lời bên trong app Principle trên macOS, không phải trong cửa sổ chat.

        Model đang chạy là model người dùng đã chọn trong app. Tự trả lời theo khung của
        skill: KHÔNG delegate phán đoán sang model khác, không hỏi xin phép để gọi model
        khác. Model nhỏ thì nói một dòng ở đầu rằng phán đoán sẽ kém hơn Fable, rồi vẫn
        chạy đủ khung.

        Đóng vòng lặp trí nhớ theo CLAUDE.md của repo, không bỏ bước: đọc memory/MEMORY.md
        và goals/GOALS.md trước khi chẩn đoán; sau khi đã chốt hướng, ghi file
        memory/cases/YYYY-MM-DD-slug.md theo memory/cases/_TEMPLATE.md và thêm một dòng vào
        index trong MEMORY.md. Ghi file xong rồi mới viết câu trả lời cuối cùng — dòng
        trailer phải là thứ cuối cùng bạn xuất ra.

        Ghi đè Bước 4 của skill ask-ray:
        - KHÔNG tạo artifact dưới bất kỳ dạng nào: không gọi tool artifact, không publish,
          không dựng HTML/JSX/trang web. App tự dựng thẻ nguyên tắc từ dòng trailer bên dưới.
        - Câu trả lời chỉ gồm đoạn text định hướng (đúng bốn ý của Bước 4), rồi dòng trailer.

        Dòng cuối cùng của mọi câu trả lời phải là đúng một dòng, không có gì sau nó:
        \(TrailerParser.marker) {"ids":["life:5.6","work:2.1"]}
        - Dùng trường `id` của corpus, KHÔNG dùng `num` — cùng một số hiệu tồn tại ở cả hai
          phần sách, chỉ `id` là duy nhất.
        - Tối đa 3 id, theo đúng thứ tự đã dùng trong câu trả lời.
        - Không grep ra nguyên tắc nào thì nói thẳng điều đó trong phần text và trả về
          \(TrailerParser.marker) {"ids":[]}. Không bịa id.
        """

    /// The flag pair every turn carries.
    public static var systemPromptArguments: [String] {
        ["--append-system-prompt", systemPrompt]
    }

    /// What to send for this turn. The engine keeps the conversation itself via
    /// `--resume`, so only a turn that starts a fresh engine session needs the
    /// framing — a follow-up is just the question.
    public static func text(for session: ChatSession, question: String) -> String {
        switch session.nextTurnStart {
        case .fresh:
            return firstTurn(topic: session.topic, question: question)
        case .resume:
            return question
        case .freshWithSeed:
            // The transcript can hold nothing but the unanswered question — the
            // consult never actually started, so it opens rather than resumes.
            guard session.messages.contains(where: { $0.role == .assistant }) else {
                return firstTurn(topic: session.topic, question: question)
            }
            return TranscriptSeed.prompt(for: session, question: question)
        }
    }

    /// Opens the consult by name: the skill carries the whole method, so the app
    /// only supplies the case.
    static func firstTurn(topic: String, question: String) -> String {
        """
        /ask-ray Chủ đề: \(topic)

        Tình huống:
        \(question)
        """
    }
}
