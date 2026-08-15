import Foundation
import Testing

@testable import PrincipleCore

/// The citation half of a session file: the diagnosis and the per-principle
/// bridge are model-authored and unreproducible, so they have to survive the
/// disk round-trip or reopening a session loses cards it can never rebuild
/// (KTD3).
@Suite("SessionStore — chẩn đoán và câu bắc cầu")
struct SessionStoreCitationTests {
    private let cited = ChatMessage(
        role: .assistant,
        text: "Bắt đầu từ chẩn đoán.",
        diagnosis: Diagnosis(kind: "Ca cửa một chiều", why: "Nhận rồi thì một năm sau mới rút ra được."),
        principles: [
            PrincipleRef(id: "life:5.6", apply: "Bạn đang cân cảm giác chắc chắn, chưa cân giá trị kỳ vọng."),
            PrincipleRef(id: "work:2.1", apply: "Bất đồng trong đội đang bị để lộ ra muộn."),
        ]
    )

    @Test("Round-trip: chẩn đoán và từng câu bắc cầu về đúng nguyên văn")
    func citationSurvivesTheRoundTrip() throws {
        let repo = try TempRepo(prefix: "citation")
        let store = repo.sessions
        let created = try store.create(topic: "Chọn giữa hai lời mời", model: ModelAlias.fable)
        _ = try store.appendMessage(cited, to: created.id)

        let reloaded = try store.load(id: created.id)
        let answer = try #require(reloaded.messages.last)
        #expect(answer.diagnosis == cited.diagnosis)
        #expect(answer.principles == cited.principles)
        #expect(answer.principleIDs == ["life:5.6", "work:2.1"])
        #expect(answer.principles.first?.apply.hasPrefix("Bạn đang cân") == true)

        let raw = try String(contentsOf: store.fileURL(for: created.id), encoding: .utf8)
        #expect(raw.contains("\"diagnosis\""))
        #expect(raw.contains("\"apply\""))
    }

    @Test("File phiên cũ chỉ có principle_ids vẫn mở được, thẻ vẫn dựng, không có bắc cầu")
    func decodesALegacySessionFile() throws {
        let repo = try TempRepo(prefix: "citation")
        let store = repo.sessions
        let created = try store.create(topic: "Ca cũ", model: ModelAlias.fable)
        let id = UUID().uuidString.lowercased()
        // Hand-written in the shape the app wrote before the rich trailer.
        let legacy = """
            {
              "id": "\(created.id.uuidString.lowercased())",
              "topic": "Ca cũ",
              "created_at": "2026-08-01T09:00:00Z",
              "model": "\(ModelAlias.fable)",
              "claude_session_id": null,
              "messages": [
                {
                  "id": "\(id)",
                  "role": "assistant",
                  "text": "Trả lời cũ.",
                  "sent_at": "2026-08-01T09:01:00Z",
                  "principle_ids": ["life:5.6", "life:1.8"]
                }
              ]
            }
            """
        try legacy.write(to: store.fileURL(for: created.id), atomically: true, encoding: .utf8)

        let reloaded = try store.load(id: created.id)
        let answer = try #require(reloaded.messages.last)
        #expect(answer.text == "Trả lời cũ.")
        #expect(answer.principleIDs == ["life:5.6", "life:1.8"])
        #expect(answer.principles.allSatisfy { $0.displayApply == nil })
        #expect(answer.diagnosis == nil)

        // Saving it back rewrites it in the new shape without losing the ids.
        try store.save(reloaded)
        #expect(try store.load(id: created.id).messages.last?.principleIDs == ["life:5.6", "life:1.8"])
    }
}
