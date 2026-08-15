import Foundation
import Testing

@testable import PrincipleCore

private let question = "Tôi đang phân vân giữa hai lời mời làm việc."

private func session(
    topic: String = "Chọn việc",
    claudeSessionID: String? = nil,
    messages: [ChatMessage] = []
) -> ChatSession {
    ChatSession(
        topic: topic,
        model: ModelAlias.default,
        claudeSessionID: claudeSessionID,
        messages: messages)
}

@Suite("ConsultPrompt")
struct ConsultPromptTests {
    // MARK: - 1. Shape per turn

    @Test("Lượt đầu mời skill theo tên, kèm chủ đề và tình huống")
    func firstTurnOpensTheConsult() {
        let text = ConsultPrompt.text(for: session(), question: question)

        #expect(text.contains("/ask-ray"))
        #expect(text.contains("Chọn việc"))
        #expect(text.hasSuffix(question))
        #expect(!text.contains(TranscriptSeed.header))
    }

    @Test("Lượt sau chỉ là câu hỏi — engine đã giữ ngữ cảnh qua --resume")
    func laterTurnsSendOnlyTheQuestion() {
        let previous = session(
            claudeSessionID: "eng-1",
            messages: [
                ChatMessage(role: .user, text: "Câu hỏi đầu."),
                ChatMessage(role: .assistant, text: "Trả lời đầu."),
            ])

        #expect(ConsultPrompt.text(for: previous, question: question) == question)
    }

    @Test("Ngữ cảnh engine mất thì lượt mới mang theo tóm tắt transcript (KTD2)")
    func freshWithSeedCarriesTheTranscript() {
        let orphaned = session(messages: [
            ChatMessage(role: .user, text: "Tôi hút một gói mỗi ngày."),
            ChatMessage(role: .assistant, text: "Bắt đầu từ chẩn đoán."),
        ])

        let text = ConsultPrompt.text(for: orphaned, question: question)

        #expect(text.contains(TranscriptSeed.header))
        #expect(text.contains("Tôi hút một gói mỗi ngày."))
        #expect(text.hasSuffix(question))
        // A seeded turn continues a consult; it does not open a second one.
        #expect(!text.contains("/ask-ray"))
    }

    @Test("Transcript mới chỉ có câu hỏi chưa được trả lời thì vẫn là lượt đầu")
    func unansweredTranscriptStillOpensTheConsult() {
        let unanswered = session(messages: [ChatMessage(role: .user, text: question)])

        let text = ConsultPrompt.text(for: unanswered, question: question)

        #expect(text.contains("/ask-ray"))
        #expect(!text.contains(TranscriptSeed.header))
    }

    // MARK: - 2. System prompt (KTD3)

    @Test("System prompt ép đúng token trailer mà app đọc được")
    func systemPromptDemandsTheTrailer() {
        let prompt = ConsultPrompt.systemPrompt

        #expect(prompt.contains(TrailerParser.marker))
        // The contract line, spelled out: the prompt is a wire format, and the
        // engine has no way to know what the app renamed the marker to.
        #expect(prompt.contains("PRINCIPLES_JSON: {\"diagnosis\":{\"kind\":"))
        #expect(prompt.contains("\"principles\":[{\"id\":\"life:4.3e\",\"apply\":"))
        // Cards are keyed by corpus id: `num` collides across the two parts.
        #expect(prompt.contains("`id`"))
        #expect(prompt.contains("`num`"))
        // Nothing cited is a valid answer, and must not become an invented id.
        #expect(prompt.contains("`\"principles\":[]`"))
        #expect(prompt.contains("Không bịa id."))
        // e2e-smoke.sh reads this prompt out of the source file with awk, so an
        // interpolated marker would reach a real engine as literal `\(...)`.
        #expect(!prompt.contains("\\("))
    }

    /// The bug this contract replaced: a real run cited 4.3e, 4.3c and 2.6 in
    /// the prose and returned a single id, so two of the three cards never
    /// existed.
    @Test("System prompt buộc mọi số hiệu nhắc trong bài phải có trong trailer")
    func systemPromptDemandsEveryCitedPrincipleInTheTrailer() {
        let prompt = ConsultPrompt.systemPrompt

        #expect(prompt.contains("MỌI số hiệu"))
        #expect(prompt.contains("đừng nhắc số hiệu của nó trong bài"))
        #expect(prompt.contains("1–3"))
        // The bridge is model-authored; title and quote are read from the corpus.
        #expect(prompt.contains("`apply` do bạn viết"))
        #expect(prompt.contains("đừng chép lại tiêu đề"))
    }

    @Test("System prompt đặt giọng Ray: ngôi thứ nhất, gọi người dùng là bạn")
    func systemPromptSetsRaysVoice() {
        let prompt = ConsultPrompt.systemPrompt

        #expect(prompt.contains("Ray Dalio"))
        #expect(prompt.contains("ngôi thứ nhất"))
        #expect(prompt.contains("xưng \"tôi\""))
        #expect(prompt.contains("Gọi người dùng là \"bạn\""))
        // MEMORY.md and the repo rules say "anh"; inside the app they lose.
        #expect(prompt.contains("Anh Danny"))
        #expect(prompt.contains("MEMORY.md"))
        // The skill forbids first person outright — say which rule is reversed.
        #expect(prompt.contains("Không đóng vai Ray Dalio"))
        // Reversing the voice must not loosen the rule that matters most.
        #expect(prompt.contains("không bịa nguyên tắc"))
    }

    @Test("System prompt huỷ Bước 4: không artifact dưới bất kỳ dạng nào")
    func systemPromptOverridesTheArtifactStep() {
        let prompt = ConsultPrompt.systemPrompt

        #expect(prompt.contains("Bước 4"))
        #expect(prompt.contains("artifact"))
        #expect(prompt.contains("publish"))
    }

    /// Both clauses were added because a real haiku turn broke on them: the skill
    /// asks a small model to hand the judgment to Fable, and nothing else made
    /// the case file get written.
    @Test("System prompt giữ phán đoán ở model người dùng chọn và bắt đóng vòng lặp trí nhớ")
    func systemPromptKeepsTheTurnSelfContained() {
        let prompt = ConsultPrompt.systemPrompt

        #expect(prompt.contains("KHÔNG delegate"))
        #expect(prompt.contains("memory/cases/"))
        #expect(prompt.contains("memory/MEMORY.md"))
        // Restated at the end as an order: a real haiku run read memory/ and
        // then answered without writing the case file until this line existed.
        #expect(prompt.contains("Thứ tự bắt buộc của một lượt"))
        #expect(prompt.contains("Chưa ghi file ca mà đã trả lời"))
    }

    @Test("Trailer đi kèm mọi lượt qua --append-system-prompt")
    func systemPromptTravelsAsAnArgument() {
        #expect(ConsultPrompt.systemPromptArguments == ["--append-system-prompt", ConsultPrompt.systemPrompt])
    }

    /// The parser is the only consumer of the instruction above; if the two ever
    /// disagree the engine complies and the app still draws nothing.
    @Test("Trailer engine được dạy viết ra thì parser đọc được")
    func theInstructedTrailerParses() {
        let answer = """
            Đây là ca quyết định.
            PRINCIPLES_JSON: {"diagnosis":{"kind":"Ca cửa một chiều","why":"Nhận rồi khó rút ra."},\
            "principles":[{"id":"life:5.6","apply":"Bạn đang cân cảm giác chắc chắn."}]}
            """

        let parsed = TrailerParser.parse(answer)

        #expect(parsed.text == "Đây là ca quyết định.")
        #expect(parsed.diagnosis?.kind == "Ca cửa một chiều")
        #expect(parsed.principleIDs == ["life:5.6"])
        #expect(parsed.principles.first?.apply == "Bạn đang cân cảm giác chắc chắn.")
    }
}
