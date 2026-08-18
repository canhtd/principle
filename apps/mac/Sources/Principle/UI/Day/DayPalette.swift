import DesignSystem
import PrincipleCore
import SwiftUI

/// The only colours this screen spells itself.
///
/// Everything structural — panels, rows, text, borders — comes from
/// `DesignSystem`. What cannot come from there is the category palette: Eden has
/// no notion of "the user's own kinds of activity", and the whole point of a
/// category colour is that Danny chose it. The keys are the store's
/// (``JournalPalette``); the values are here, because a hex in `categories.jsonl`
/// would freeze today's theme into the repo for good.
enum DayPalette {
    /// The six a category can wear, in the order they are handed out. Muted
    /// enough to sit on Eden's warm canvas without shouting at the type.
    static let colors: [String: Color] = [
        "olive": EdenColor.olive,
        "blueberry": EdenColor.hex(0x4F6B7A),
        "clay": EdenColor.hex(0xA35D3D),
        "plum": EdenColor.hex(0x6A4C7A),
        "sand": EdenColor.hex(0x7A6A3C),
        "slate": EdenColor.hex(0x2F4F66),
    ]

    /// A category's colour, or the neutral an untagged task wears — the state a
    /// task is left in when its category is deleted.
    static func color(_ category: JournalCategory?) -> Color {
        guard let category else { return EdenColor.n500 }
        return colors[category.colorKey] ?? colors[JournalPalette.fallbackColorKey] ?? EdenColor.n500
    }

    /// The current-time line. Not an Eden token — Eden has no clock — and
    /// deliberately the one warm red on the screen, so it is never mistaken for
    /// a category.
    static let now = EdenColor.hex(0xC8402A)
}

/// How a task is filled on the grid: Must reads as a solid object, Nice-to as a
/// tint of the same colour (spec #5 rev 2). One decision, in one place, because
/// blocks and all-day chips have to agree — a chip that changes shade when it is
/// dragged onto the grid would look like a different task.
struct TaskFill {
    let background: Color
    let foreground: Color
    let border: Color

    init(category: JournalCategory?, priority: Priority) {
        let color = DayPalette.color(category)
        switch priority {
        case .must:
            background = color
            foreground = .white
            border = .clear
        case .nice:
            background = color.opacity(0.18)
            foreground = EdenColor.textPrimary
            border = color.opacity(0.34)
        }
    }

    init(_ row: PlannedTask) {
        self.init(category: row.category, priority: row.priority)
    }
}
