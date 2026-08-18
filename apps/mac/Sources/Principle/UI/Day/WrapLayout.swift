import SwiftUI

/// Lays chips out left to right and wraps them, the way text wraps.
///
/// SwiftUI has no flow container, and the all-day strip needs one: a row of
/// chips that grows to a second line rather than squeezing or clipping. Written
/// as a `Layout` rather than faked with a grid so that a long title takes the
/// width it needs instead of a column's share of it.
struct WrapLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let lines = wrap(subviews, into: width)
        let height = lines.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, lines.count - 1))
        return CGSize(width: proposal.width ?? lines.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in wrap(subviews, into: bounds.width) {
            var x = bounds.minX
            for item in line.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private struct Line {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func wrap(_ subviews: Subviews, into width: CGFloat) -> [Line] {
        var lines: [Line] = []
        var line = Line()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            // The first chip on a line always stays on it, however wide it is —
            // wrapping it away would leave an empty line above a chip that still
            // does not fit.
            if !line.items.isEmpty, line.width + spacing + size.width > width {
                lines.append(line)
                line = Line()
            }
            if !line.items.isEmpty { line.width += spacing }
            line.items.append((index: index, size: size))
            line.width += size.width
            line.height = max(line.height, size.height)
        }
        if !line.items.isEmpty { lines.append(line) }
        return lines
    }
}
