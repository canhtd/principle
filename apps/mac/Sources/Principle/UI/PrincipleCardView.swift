import PrincipleCore
import SwiftUI

/// The cards under one of Ray's answers.
///
/// Every card comes from the local corpus, resolved from the ids the engine
/// cited (KTD3). Nothing here is generated: no cited id means no card (AE2).
struct PrincipleCardList: View {
    let principles: [PrincipleRecord]
    /// Injected by U6; until then the card shows the affordances inert.
    var isFavorite: (PrincipleRecord) -> Bool = { _ in false }
    var toggleFavorite: (PrincipleRecord) -> Void = { _ in }
    var showChapterContext: (PrincipleRecord) -> Void = { _ in }

    var body: some View {
        if !principles.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(principles) { principle in
                    PrincipleCardView(
                        principle: principle,
                        isFavorite: isFavorite(principle),
                        toggleFavorite: { toggleFavorite(principle) },
                        showChapterContext: { showChapterContext(principle) }
                    )
                }
            }
            .padding(.top, 4)
        }
    }
}

/// One principle, verbatim in Vietnamese.
struct PrincipleCardView: View {
    let principle: PrincipleRecord
    var isFavorite = false
    var toggleFavorite: () -> Void = {}
    var showChapterContext: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(principle.caption)
                .font(Typography.caption)
                .lineSpacing(Typography.captionLineSpacing)
                .foregroundStyle(.secondary)

            Text(principle.title)
                .font(Typography.title)
                .lineSpacing(Typography.titleLineSpacing)
                .textSelection(.enabled)

            // AE3: about half the corpus is a heading only. That heading is the
            // whole principle — no empty paragraph, no invented body.
            if let body = principle.displayBody {
                Text(body)
                    .vietnameseBody()
                    .textSelection(.enabled)
            }

            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary, lineWidth: 1)
        }
    }

    private var actions: some View {
        HStack(spacing: 14) {
            Button(action: toggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite ? Color.pink : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(isFavorite ? "Bỏ khỏi Yêu thích" : "Lưu vào Yêu thích")
            .accessibilityLabel(isFavorite ? "Bỏ khỏi Yêu thích" : "Lưu vào Yêu thích")

            Button("Ngữ cảnh chương", action: showChapterContext)
                .buttonStyle(.plain)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                // The handful of records outside any chapter have no context to
                // open.
                .disabled(principle.chapter.isEmpty)

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}

#Preview {
    PrincipleCardList(
        principles: [
            PrincipleRecord(
                id: "life:5.6",
                part: "Nguyên tắc sống",
                chapter: "Chương 5 — Quyết định giả lập",
                num: "5.6",
                title: "[PREVIEW] Cân giá trị kỳ vọng thay vì cảm giác chắc chắn",
                body: "[PREVIEW] Ước lượng xác suất và hệ quả của từng lựa chọn rồi chọn cái có giá trị kỳ vọng cao nhất.",
                hasBody: true
            ),
            PrincipleRecord(
                id: "work:3.4",
                part: "Nguyên tắc làm việc",
                chapter: "",
                num: "3.4",
                title: "[PREVIEW] Bản ghi chỉ có tiêu đề, không có thân bài",
                body: "",
                hasBody: false
            ),
        ]
    )
    .padding()
    .frame(width: 520)
}
