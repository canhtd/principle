import DesignSystem
import PrincipleCore
import SwiftUI

/// The principle card, in column 1 and in the chat: a 3 pt accent stroke inside
/// the radius, an uppercase `LIFE PRINCIPLE 5.3` label, the title, and the
/// bookmark toggle (decision 4).
///
/// The card carries no excerpt — clicking it opens one beside it (decision 5).
struct PrincipleCardSmall: View {
    let record: PrincipleRecord
    let favorites: FavoritesModel
    @Bindable var ui: DayShellState

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: EdenMetric.sidebarInset) {
                Text(PrincipleLabel.text(for: record))
                    .font(EdenFont.ui(10.5, .semibold))
                    .tracking(10.5 * 0.08)
                    .foregroundStyle(EdenColor.n500)
                    .frame(maxWidth: .infinity, alignment: .leading)
                FavoriteToggle(id: record.id, favorites: favorites)
                    .offset(x: 3, y: -3)
            }
            Text(record.title)
                .font(EdenFont.ui(13.5))
                .lineSpacing(13.5 * 0.5)
                .foregroundStyle(EdenColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 11)
        .padding(.leading, 16)
        .padding(.trailing, 13)
        .background(EdenColor.card)
        .overlay(alignment: .leading) { DayPalette.now.opacity(0).frame(width: 0) }
        .overlay(alignment: .leading) { EdenColor.primary.frame(width: 3) }
        .clipShape(.rect(cornerRadius: EdenRadius.md, style: .continuous))
        .edenBorder(EdenColor.black(isHovering ? 12 : 6), radius: EdenRadius.md)
        .shadow(color: EdenColor.black(isHovering ? 6 : 4), radius: isHovering ? 4 : 1.5, y: 1)
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .onTapGesture { ui.openPrincipleID = record.id }
        .principleExcerpt(record: record, favorites: favorites, ui: ui)
    }
}

/// The bookmark, wherever a principle is shown.
struct FavoriteToggle: View {
    let id: String
    let favorites: FavoritesModel

    @State private var isHovering = false

    var body: some View {
        let isOn = favorites.isFavorite(id)
        Button { favorites.toggle(id) } label: {
            Image(systemName: isOn ? "bookmark.fill" : "bookmark")
                .font(EdenFont.ui(12))
                .foregroundStyle(isOn ? EdenColor.primary : (isHovering ? EdenColor.n700 : EdenColor.n400))
                .frame(width: 22, height: 22)
                .background(isHovering ? EdenColor.black(4) : .clear, in: .rect(cornerRadius: 6))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(isOn ? "Remove from favourites" : "Add to favourites")
        .onHover { isHovering = $0 }
    }
}

/// `LIFE PRINCIPLE 5.3` — built from the record rather than stored, so it can
/// never disagree with the corpus.
enum PrincipleLabel {
    static func text(for record: PrincipleRecord) -> String {
        let book = record.id.hasPrefix("work:") ? "WORK" : "LIFE"
        let number = record.num.trimmingCharacters(in: .whitespaces)
        return number.isEmpty ? "\(book) PRINCIPLE" : "\(book) PRINCIPLE \(number)"
    }
}
