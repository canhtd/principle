import PrincipleCore
import SwiftUI

/// One principle in full, opened from its card.
///
/// The room the card is a door to: the book's whole passage, what it costs to
/// keep (♥), where it sits in the chapter, and — when the engine wrote one — the
/// bridge into this case. Still nothing generated: every word here is either the
/// corpus or the engine's own `apply` (AE2).
struct PrincipleDetailView: View {
    let card: PrincipleCardModel
    /// Read inside `body`, so the heart follows the store rather than a copy of
    /// it taken when the sheet opened.
    var isFavorite: () -> Bool = { false }
    var toggleFavorite: () -> Void = {}
    /// The chapter to open, or `nil` for a record that sits in none. Opened as a
    /// sheet of this sheet, so the transcript underneath is never disturbed.
    var chapterContext: () -> ChapterContext? = { nil }

    @Environment(\.dismiss) private var dismiss
    @State private var context: ChapterContext?

    var body: some View {
        VStack(spacing: 0) {
            chrome
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    label
                    title
                    actions
                    Divider().padding(.top, Spacing.cardBlock)
                    passage
                    applied
                    attribution
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sheetPadding)
                .padding(.bottom, Spacing.sheetPadding)
            }
        }
        .frame(width: Typography.sheetWidth, height: Typography.sheetHeight)
        .sheet(item: $context) { ChapterContextView(context: $0) }
    }

    // MARK: - Header

    private var chrome: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(Typography.title)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            // Esc still closes; the focus ring around a bare glyph reads as a
            // broken icon rather than as a control.
            .focusEffectDisabled()
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Close")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.sheetPadding)
        .padding(.top, Spacing.sheetChrome)
    }

    /// The number belongs here rather than on the card: this is where there is
    /// room to place the principle in the system it came from.
    private var label: some View {
        HStack(alignment: .top, spacing: Spacing.cardRow) {
            Rectangle()
                .fill(Palette.red)
                .frame(width: 3)
            Text(card.detailLabel)
                .font(Typography.label)
                .tracking(Typography.labelTracking)
                .lineSpacing(Typography.labelLineSpacing)
                .foregroundStyle(Palette.red)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, Spacing.cardBlock)
    }

    private var title: some View {
        Text(card.title)
            .font(Typography.detailTitle)
            .tracking(Typography.detailTitleTracking)
            .lineSpacing(Typography.detailTitleLineSpacing)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Spacing.cardBlock)
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: Spacing.sheetPadding) {
            favoriteButton
            chapterButton
            Spacer(minLength: 0)
        }
        .padding(.top, Spacing.cardBlock)
    }

    private var favoriteButton: some View {
        Button(action: toggleFavorite) {
            Label {
                Text("Favorite")
            } icon: {
                Image(systemName: isFavorite() ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite() ? Palette.red : .secondary)
            }
        }
        .buttonStyle(.plain)
        .font(Typography.body)
        .help(isFavorite() ? "Remove from favorites" : "Save to favorites")
        .accessibilityLabel(isFavorite() ? "Remove from favorites" : "Save to favorites")
    }

    private var chapterButton: some View {
        Button(action: { context = chapterContext() }) {
            Label("Chapter context", systemImage: "book")
        }
        .buttonStyle(.plain)
        .font(Typography.body)
        // The handful of records outside any chapter have no context to open.
        .disabled(card.record.chapter.isEmpty)
        .opacity(card.record.chapter.isEmpty ? 0.4 : 1)
    }

    // MARK: - The book

    /// AE3: a heading-only record shows its heading and stops. Nothing is
    /// written to fill the space.
    @ViewBuilder
    private var passage: some View {
        if let body = card.record.detailBody {
            MarkdownText(text: body)
                .padding(.top, Spacing.sheetPadding)
        }
    }

    @ViewBuilder
    private var applied: some View {
        if let apply = card.apply {
            VStack(alignment: .leading, spacing: Spacing.cardSnug) {
                Text("APPLIED TO THIS CASE")
                    .font(Typography.smallLabel)
                    .tracking(Typography.smallLabelTracking)
                    .foregroundStyle(.secondary)
                Text(apply)
                    .vietnameseBody()
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.cardBlock)
            .background(
                Palette.diagnosisBackground,
                in: RoundedRectangle(cornerRadius: Palette.diagnosisRadius)
            )
            .padding(.top, Spacing.sheetPadding)
        }
    }

    private var attribution: some View {
        Text("From *Principles: Life & Work* (Vietnamese edition)")
            .font(Typography.caption)
            .lineSpacing(Typography.captionLineSpacing)
            .foregroundStyle(.tertiary)
            .padding(.top, Spacing.sheetPadding)
    }
}

#Preview {
    // [PREVIEW] fixture — never the real translation, which is gitignored.
    let record = PrincipleRecord(
        id: "life:4.3e",
        part: "Nguyên tắc sống",
        chapter: "Chương 4 — Quyết định giả lập",
        num: "4.3e",
        title: "[PREVIEW] Đừng để bị phân tâm bởi những thứ hào nhoáng.",
        body: "[PREVIEW] a. Người lập kế hoạch giỏi mà không thực thi thì chẳng đi tới đâu.b. Thói quen làm việc tốt bị đánh giá thấp một cách nghiêm trọng.c. Hãy đi tới cùng.",
        hasBody: true
    )
    return PrincipleDetailView(
        card: PrincipleCardModel(record: record, apply: "[PREVIEW] Anh đang đổi hướng lần thứ ba trong một quý.")
    )
}
