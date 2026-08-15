import PrincipleCore
import SwiftUI

/// One principle, drawn the way `references/artifact-spec.md` asks for it: a
/// black card, a red label carrying the number, the title verbatim from the
/// book, and — behind a disclosure — the quote and the bridge into this case.
///
/// Collapsed by default on purpose: three open cards are a wall of text, and
/// the title is what the reader scans first.
struct PrincipleCardView: View {
    let card: PrincipleCardModel
    var isFavorite = false
    var toggleFavorite: () -> Void = {}
    var showChapterContext: () -> Void = {}

    @State private var isExpanded: Bool

    /// `expanded` is for previews and design renders only — in the chat every
    /// card starts shut.
    init(
        card: PrincipleCardModel,
        isFavorite: Bool = false,
        toggleFavorite: @escaping () -> Void = {},
        showChapterContext: @escaping () -> Void = {},
        expanded: Bool = false
    ) {
        self.card = card
        self.isFavorite = isFavorite
        self.toggleFavorite = toggleFavorite
        self.showChapterContext = showChapterContext
        _isExpanded = State(initialValue: expanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            label
            title
            controls
            if isExpanded { revealed }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.cardPadding)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Palette.cardRadius))
        .overlay {
            // Keeps the card an object rather than a hole when the window is
            // itself dark.
            RoundedRectangle(cornerRadius: Palette.cardRadius)
                .strokeBorder(Palette.cardHairline, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: Palette.cardRadius))
        .onTapGesture(perform: toggleExpanded)
    }

    private func toggleExpanded() {
        guard card.isExpandable else { return }
        withAnimation(.easeOut(duration: 0.15)) { isExpanded.toggle() }
    }

    // MARK: - Header

    /// The one place the spec lets itself be loud: the principle's number is
    /// real information — where this sits in the system — so it gets the bar.
    private var label: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Palette.red)
                .frame(width: 3)
            Text(card.label)
                .font(Typography.label)
                .tracking(Typography.labelTracking)
                .lineSpacing(Typography.labelLineSpacing)
                .foregroundStyle(Palette.red)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var title: some View {
        Text(card.title)
            .font(Typography.cardTitle)
            .tracking(Typography.cardTitleTracking)
            // Vietnamese marks stack above and below; 1.35 is the floor.
            .lineSpacing(Typography.cardTitleLineSpacing)
            .foregroundStyle(Palette.cardTitle)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)
    }

    // MARK: - Controls

    /// Disclosure on the left, the affordances that outlive the card on the
    /// right — a favourite must stay one click away while the card is shut.
    private var controls: some View {
        HStack(spacing: 16) {
            if card.isExpandable { disclosure }
            Spacer(minLength: 8)
            favoriteButton
            chapterButton
        }
        .padding(.top, 12)
    }

    private var disclosure: some View {
        Button(action: toggleExpanded) {
            HStack(spacing: 6) {
                Text(disclosureTitle)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(Palette.cardMuted)
        }
        .buttonStyle(.plain)
        .font(Typography.caption)
        .accessibilityLabel(disclosureTitle)
    }

    private var disclosureTitle: String {
        if isExpanded { return "Hide" }
        return card.hasApply ? "Why this applies" : "The book’s words"
    }

    private var favoriteButton: some View {
        Button(action: toggleFavorite) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundStyle(isFavorite ? Palette.red : Palette.cardMuted)
        }
        .buttonStyle(.plain)
        .help(favoriteTitle)
        .accessibilityLabel(favoriteTitle)
    }

    private var favoriteTitle: String {
        isFavorite ? "Remove from favorites" : "Save to favorites"
    }

    private var chapterButton: some View {
        Button("Chapter context", action: showChapterContext)
            .buttonStyle(.plain)
            .font(Typography.caption)
            .foregroundStyle(Palette.cardMuted)
            // The handful of records outside any chapter have no context to open.
            .disabled(card.record.chapter.isEmpty)
            .opacity(card.record.chapter.isEmpty ? 0.4 : 1)
    }

    // MARK: - Behind the disclosure

    @ViewBuilder
    private var revealed: some View {
        if let quote = card.quote {
            Text("“\(quote)”")
                .vietnameseBody()
                .foregroundStyle(Palette.cardQuote)
                .textSelection(.enabled)
                // Long prose asked for its ideal size is one endless line; this
                // is what makes it wrap into the width it was given instead.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
        }
        if let apply = card.apply {
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(Palette.cardHairline)
                    .frame(height: 1)
                    .padding(.bottom, 8)
                Text("APPLIED TO THIS CASE")
                    .font(Typography.smallLabel)
                    .tracking(Typography.smallLabelTracking)
                    .foregroundStyle(Palette.cardMuted)
                Text(apply)
                    .vietnameseBody()
                    .foregroundStyle(Palette.cardApply)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
        }
    }
}
