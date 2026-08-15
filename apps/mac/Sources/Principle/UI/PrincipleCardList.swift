import PrincipleCore
import SwiftUI

/// What sits under one of Ray's answers: what kind of case this is, then the
/// principles it was decided by.
///
/// Everything here comes from the local corpus, resolved from the ids the
/// engine cited (KTD3). Nothing is generated: no cited id means no card, and no
/// diagnosis means no header (AE2).
struct PrincipleCardList: View {
    var diagnosis: Diagnosis?
    var cards: [PrincipleCardModel] = []
    var isFavorite: (PrincipleRecord) -> Bool = { _ in false }
    var toggleFavorite: (PrincipleRecord) -> Void = { _ in }
    var showChapterContext: (PrincipleRecord) -> Void = { _ in }

    var body: some View {
        if diagnosis != nil || !cards.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                if let diagnosis {
                    DiagnosisHeaderView(diagnosis: diagnosis)
                }
                ForEach(cards) { card in
                    PrincipleCardView(
                        card: card,
                        isFavorite: isFavorite(card.record),
                        toggleFavorite: { toggleFavorite(card.record) },
                        showChapterContext: { showChapterContext(card.record) }
                    )
                }
            }
            .frame(maxWidth: Typography.cardWidth, alignment: .leading)
            .padding(.top, 4)
        }
    }
}

extension PrincipleCardList {
    /// Records with no case attached — the Favorites section, where a saved
    /// principle reads the way it did when Ray cited it, minus the bridge.
    init(
        principles: [PrincipleRecord],
        isFavorite: @escaping (PrincipleRecord) -> Bool = { _ in false },
        toggleFavorite: @escaping (PrincipleRecord) -> Void = { _ in },
        showChapterContext: @escaping (PrincipleRecord) -> Void = { _ in }
    ) {
        self.init(
            diagnosis: nil,
            cards: PrincipleCardModel.cards(for: principles),
            isFavorite: isFavorite,
            toggleFavorite: toggleFavorite,
            showChapterContext: showChapterContext
        )
    }
}

/// Bước 1 of the consultation, drawn where the cards are: naming the kind of
/// case is what decided which principles were looked up at all.
///
/// Light panel against the black stack below — the two registers are what make
/// the answer scannable.
struct DiagnosisHeaderView: View {
    let diagnosis: Diagnosis

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DIAGNOSIS")
                .font(Typography.label)
                .tracking(Typography.labelTracking)
                .lineSpacing(Typography.labelLineSpacing)
                .foregroundStyle(Palette.red)
            if !diagnosis.kind.isEmpty {
                Text(diagnosis.kind)
                    .font(Typography.title)
                    .lineSpacing(Typography.titleLineSpacing)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !diagnosis.why.isEmpty {
                Text(diagnosis.why)
                    .vietnameseBody()
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            Palette.diagnosisBackground,
            in: RoundedRectangle(cornerRadius: Palette.diagnosisRadius)
        )
    }
}

#Preview {
    // [PREVIEW] fixture: a principle with a body, one heading-only, and one
    // cited the legacy way — no bridge text.
    let records = [
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
            id: "work:13.5c",
            part: "Nguyên tắc làm việc",
            chapter: "",
            num: "13.5c",
            title: "[PREVIEW] Bản ghi chỉ có tiêu đề, không có thân bài",
            body: "",
            hasBody: false
        ),
    ]
    return ScrollView {
        PrincipleCardList(
            diagnosis: Diagnosis(
                kind: "[PREVIEW] Ca lặp lại — vấn đề cỗ máy",
                why: "[PREVIEW] Cùng một chuyện hỏng ba lần, và lần nào cũng chữa bằng tay."
            ),
            cards: [
                PrincipleCardModel(record: records[0], apply: "[PREVIEW] Anh đang so hai lựa chọn bằng cảm giác."),
                PrincipleCardModel(record: records[1], apply: "[PREVIEW] Ba tuần nay anh loại phương án B."),
                PrincipleCardModel(record: records[0]),
            ]
        )
        .padding(20)
    }
    .frame(width: 600, height: 640)
}
