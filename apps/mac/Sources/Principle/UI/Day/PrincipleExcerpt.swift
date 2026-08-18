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
            PrincipleExcerptView(record: record, favorites: favorites, maxHeight: ui.excerptMaxHeight)
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
///
/// The book is quoted in full, however long the passage is (AE2 cuts both ways —
/// the app must not invent text, and must not swallow it either). A principle's
/// body runs from a single line to a page and a half, so the reading scrolls
/// once it passes ``maxHeight`` while the two actions stay pinned under it —
/// a passage you have to scroll must not put Favorite out of reach.
struct PrincipleExcerptView: View {
    let record: PrincipleRecord
    let favorites: FavoritesModel
    /// How tall this may grow before the reading scrolls instead.
    var maxHeight: CGFloat = 480

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                reading
            }
            // Sized to the passage, capped at the window's 60 %. `fixedSize`
            // makes the scroll view take its *content's* height instead of
            // every point it is offered — otherwise a one-line principle opens
            // a popover half a screen tall — and the cap then clamps a long one,
            // at which point it starts scrolling. Measured in one layout pass,
            // which a popover needs: it sizes its window from the first one.
            .frame(maxHeight: maxHeight)
            .fixedSize(horizontal: false, vertical: true)
            .scrollIndicators(.automatic)

            Divider().padding(.top, 16).padding(.bottom, 12)
            actions
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 360)
    }

    private var reading: some View {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The book verbatim, never assembled (AE2). A heading-only record has no
    /// body to quote, and that heading *is* the principle (AE3) — so the
    /// popover says so rather than inventing a passage to fill the space.
    ///
    /// `displayBody`, not `quote`: `quote` is the 40-word card cut and ends in
    /// an `…` by construction. This is the place the passage is *read*, so it is
    /// the whole passage — the popover scrolls instead of eliding.
    @ViewBuilder
    private var quote: some View {
        if let quote = record.displayBody {
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
    ///
    /// It wraps rather than truncating: with the book's name in front, a second
    /// line costs nothing, and nothing in this popover should end in an ellipsis.
    private var source: some View {
        Text(record.chapter.isEmpty ? "Principles, Ray Dalio" : "Principles, Ray Dalio · \(record.chapter)")
            .font(EdenFont.ui(11))
            .foregroundStyle(EdenColor.n400)
            .fixedSize(horizontal: false, vertical: true)
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
