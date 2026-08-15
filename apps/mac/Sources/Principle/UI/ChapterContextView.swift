import PrincipleCore
import SwiftUI

/// The chapter one principle sits in (R8), opened as a sheet from a card or a
/// favourite.
///
/// Read-only on purpose: it is the corpus in its own order, with the principle
/// you came from marked — nothing here is written and nothing is generated.
struct ChapterContextView: View {
    let context: ChapterContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if context.hasContext {
                list
            } else {
                empty
            }
        }
        .frame(width: 560, height: 560)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ngữ cảnh chương")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                Text(context.chapter.isEmpty ? context.current.part : context.chapter)
                    .font(Typography.title)
                    .lineSpacing(Typography.titleLineSpacing)
            }
            Spacer(minLength: 0)
            Button("Đóng") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(context.principles) { principle in
                        ChapterRow(principle: principle, isCurrent: context.isCurrent(principle))
                            .id(principle.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            // Open where the reader already was, not at the top of the chapter.
            .onAppear { proxy.scrollTo(context.current.id, anchor: .center) }
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("Không có ngữ cảnh chương", systemImage: "book.closed")
        } description: {
            Text(ChapterContext.noChapterMessage)
        }
        .frame(maxHeight: .infinity)
    }
}

/// One neighbouring principle. The one the sheet was opened from keeps its
/// place in the chapter rather than being lifted out of it.
private struct ChapterRow: View {
    let principle: PrincipleRecord
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(principle.num)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                if isCurrent {
                    Text("Đang xem")
                        .font(Typography.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }

            Text(principle.title)
                .font(Typography.title)
                .lineSpacing(Typography.titleLineSpacing)
                .textSelection(.enabled)

            // AE3: a heading-only record shows its heading and stops there.
            if let body = principle.displayBody {
                Text(body)
                    .vietnameseBody()
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            isCurrent ? AnyShapeStyle(Color.accentColor.opacity(0.12)) : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1)
            }
        }
    }
}

#Preview {
    let corpus = CorpusStore(records: [
        PrincipleRecord(
            id: "life:5.5",
            part: "Nguyên tắc sống",
            chapter: "Chương 5 — Quyết định giả lập",
            num: "5.5",
            title: "[PREVIEW] Nguyên tắc đứng ngay trước",
            body: "",
            hasBody: false
        ),
        PrincipleRecord(
            id: "life:5.6",
            part: "Nguyên tắc sống",
            chapter: "Chương 5 — Quyết định giả lập",
            num: "5.6",
            title: "[PREVIEW] Cân giá trị kỳ vọng thay vì cảm giác chắc chắn",
            body: "[PREVIEW] Ước lượng xác suất và hệ quả của từng lựa chọn rồi chọn cái có giá trị kỳ vọng cao nhất.",
            hasBody: true
        ),
    ])
    return ChapterContextView(
        context: ChapterContext(corpus: corpus, record: corpus.records[1])
    )
}
