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

    /// A real answer coined "hạ nhân" for the lower-level self — a word the
    /// Vietnamese edition never uses. Every term below was verified by grep
    /// against `references/corpus.jsonl`; the prompt may only teach words the
    /// translation actually uses.
    @Test("System prompt mang theo từ vựng của bản dịch")
    func systemPromptCarriesTheBooksGlossary() {
        let prompt = ConsultPrompt.systemPrompt

        #expect(prompt.contains("Từ của sách, dùng nguyên dạng:"))
        for term in [
            "hai bạn",
            "bạn ở cấp độ cao hơn",
            "bạn ở cấp độ thấp hơn",
            "bản ngã thấp hơn",
            "tâm thức",
            "tiềm thức",
            "Đau đớn + Suy ngẫm = Tiến bộ",
            "giá trị kỳ vọng",
            "người đáng tin cậy",
            "minh bạch triệt để",
            "cởi mở triệt để",
            "siêu thực tế",
            "Quy trình 5 bước",
            "nguyên nhân gốc rễ",
            "hậu quả bậc hai và bậc ba",
            "cỗ máy",
            "điểm mù",
            "trọng số độ tin cậy",
            "chế độ trọng dụng ý tưởng",
            "công việc có ý nghĩa",
            "Bên chịu trách nhiệm",
            "Nguyên tắc sống",
            "Nguyên tắc làm việc",
        ] {
            #expect(prompt.contains(term), "glossary is missing \(term)")
        }
        // The coinage that triggered the glossary, named so the engine can see
        // the shape of the mistake rather than only the rule against it.
        #expect(prompt.contains("KHÔNG có \"hạ nhân\""))
        #expect(prompt.contains("\"thượng nhân\""))
        // The whole glossary has to survive the awk extraction in
        // Tests/E2E/e2e-smoke.sh, which reads the literal out of the source.
        #expect(!prompt.contains("\\("))
    }

    @Test("System prompt yêu cầu văn xuôi theo nhịp của sách, không phải bảng nhãn")
    func systemPromptAsksForTheBooksProse() {
        let prompt = ConsultPrompt.systemPrompt

        #expect(prompt.contains("Văn xuôi liền mạch"))
        #expect(prompt.contains("Hãy…"))
        // The four beats of an answer stay readable even without labels.
        #expect(prompt.contains("chẩn đoán → nguyên tắc áp vào → hướng đi"))
        #expect(prompt.contains("hai nhãn in đậm"))
        // Verbatim quoting is allowed only from what the lookup returned.
        #expect(prompt.contains("Chỉ trích nguyên văn sách từ những gì lần tra corpus"))
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

    /// The system prompt rides every `--resume` turn, so an order phrased for
    /// the first turn alone reads as "write a case file" on turn 5 too — and a
    /// two-turn consult ends up as two cases in the index.
    @Test("System prompt: một session = một ca = một file, lượt sau chỉ cập nhật")
    func systemPromptKeepsOneSessionToOneCaseFile() {
        let prompt = ConsultPrompt.systemPrompt

        #expect(prompt.contains("Một session = một ca = một file"))
        #expect(prompt.contains("ĐÚNG MỘT dòng vào"))
        #expect(prompt.contains("CẬP NHẬT chính file ấy"))
        #expect(prompt.contains("KHÔNG tạo file ca thứ hai"))
        #expect(prompt.contains("KHÔNG thêm dòng index thứ"))
        // The order block is restated last on purpose; it has to carry the same
        // distinction, or recency alone re-orders a second file on every turn.
        #expect(prompt.contains("CẬP NHẬT đúng file ca đó (mọi lượt sau)"))
    }

    /// Recency is the whole reason the order block exists — nothing may be
    /// appended after it.
    @Test("Khối thứ tự bắt buộc vẫn nằm ở cuối system prompt")
    func theMandatoryOrderBlockStaysLast() throws {
        let prompt = ConsultPrompt.systemPrompt
        let order = try #require(prompt.range(of: "Thứ tự bắt buộc của một lượt"))

        #expect(prompt.hasSuffix("là lỗi, kể cả khi\ncâu trả lời đã đủ ý."))
        #expect(!prompt[order.upperBound...].contains("Một session = một ca"))
        // The glossary is long; appended after the order block it would take the
        // recency slot the order block exists to hold.
        #expect(!prompt[order.upperBound...].contains("Từ của sách"))
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
