import AppKit
import DesignSystem
import PrincipleCore
import SwiftUI

extension View {
    /// Opens the principle's excerpt in a popover beside whatever was clicked
    /// (decision 5) — not in a pane on the other side of the screen. Escape and
    /// a click away close it; clicking another principle re-anchors it.
    func principleExcerpt(record: PrincipleRecord, favorites: FavoritesModel, ui: DayShellState) -> some View {
        modifier(PrincipleExcerptModifier(record: record, favorites: favorites, ui: ui))
    }
}

private struct PrincipleExcerptModifier: ViewModifier {
    let record: PrincipleRecord
    let favorites: FavoritesModel
    @Bindable var ui: DayShellState

    func body(content: Content) -> some View {
        content.popover(isPresented: isOpen, arrowEdge: .trailing) {
            PrincipleExcerptView(record: record, favorites: favorites)
        }
    }

    /// A native popover, so the arrow, the click-away and the Escape are the
    /// window server's rather than something re-implemented here.
    private var isOpen: Binding<Bool> {
        Binding(
            get: { ui.openPrincipleID == record.id },
            set: { open in
                if open {
                    ui.openPrincipleID = record.id
                } else if ui.openPrincipleID == record.id {
                    ui.openPrincipleID = nil
                }
            }
        )
    }
}

/// The excerpt itself: the label, the title, the book's own words, where they
/// come from, and the two things you can do with them.
struct PrincipleExcerptView: View {
    let record: PrincipleRecord
    let favorites: FavoritesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(PrincipleLabel.text(for: record))
                .font(EdenFont.ui(10.5, .semibold))
                .tracking(10.5 * 0.08)
                .foregroundStyle(EdenColor.n500)

            Text(record.title)
                .font(EdenFont.ui(16, .medium))
                .lineSpacing(16 * 0.4)
                .foregroundStyle(EdenColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)
                .padding(.bottom, 12)

            quote
            source
            Divider().padding(.top, 16).padding(.bottom, 12)
            actions
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 360)
    }

    /// The book verbatim, never assembled (AE2). A heading-only record has no
    /// body to quote, and that heading *is* the principle (AE3) — so the
    /// popover says so rather than inventing a passage to fill the space.
    @ViewBuilder
    private var quote: some View {
        if let quote = record.quote {
            Text(quote)
                .font(EdenFont.ui(13.5))
                .italic()
                .lineSpacing(13.5 * 0.7)
                .foregroundStyle(EdenColor.hex(0x55524E))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 12)
                .overlay(alignment: .leading) { EdenColor.primary.frame(width: 3) }
        } else {
            Text("The book gives this principle as a heading. There is no passage under it.")
                .font(EdenFont.ui(12))
                .foregroundStyle(EdenColor.n400)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The book first, the chapter after it. A chapter title in this book is a
    /// whole sentence, and leading with it pushed the attribution off the end of
    /// the line entirely.
    private var source: some View {
        Text(record.chapter.isEmpty ? "Principles, Ray Dalio" : "Principles, Ray Dalio · \(record.chapter)")
            .font(EdenFont.ui(11))
            .foregroundStyle(EdenColor.n400)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.top, 14)
    }

    private var actions: some View {
        HStack(spacing: EdenMetric.sidebarInset) {
            let isFavorite = favorites.isFavorite(record.id)
            Button {
                favorites.toggle(record.id)
            } label: {
                Label(isFavorite ? "Favorited" : "Favorite",
                      systemImage: isFavorite ? "bookmark.fill" : "bookmark")
            }
            .buttonStyle(EdenPillButtonStyle())
            .focusEffectDisabled()

            if let book = BookLocation.principlesBookURL(override: AppSettings().bookPath) {
                Button {
                    open(book)
                } label: {
                    Label("Open in Books", systemImage: "book")
                }
                .buttonStyle(EdenPillButtonStyle())
                .focusEffectDisabled()
                .help(BookLocation.deepLinkLimitation)
            }
            Spacer(minLength: 0)
        }
    }

    /// Books, by bundle id rather than by "the default epub reader": the button
    /// says Books, so it has to be Books.
    private func open(_ book: URL) {
        guard let books = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iBooksX") else {
            NSWorkspace.shared.open(book)
            return
        }
        NSWorkspace.shared.open([book], withApplicationAt: books, configuration: NSWorkspace.OpenConfiguration())
    }
}
