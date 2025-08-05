import SwiftUI

@available(iOS 16.0, *)
struct FlowLayout: Layout {
    var spacing: CGFloat

    init(spacing: CGFloat = 12) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let containerWidth = proposal.width ?? .greatestFiniteMagnitude
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        
        guard !sizes.isEmpty else { return .zero }

        var totalHeight: CGFloat = 0
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        
        for size in sizes {
            let prospectiveWidth = currentRowWidth + size.width + (currentRowWidth == 0 ? 0 : spacing)
            if prospectiveWidth > containerWidth {
                totalHeight += currentRowHeight + (totalHeight == 0 ? 0 : spacing)
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                currentRowWidth = prospectiveWidth
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }
        
        totalHeight += currentRowHeight
        
        return CGSize(width: containerWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }

        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        
        var rows: [[(index: Int, size: CGSize)]] = []
        var currentRow: [(index: Int, size:CGSize)] = []
        var currentRowWidth: CGFloat = 0.0

        for i in subviews.indices {
            let size = sizes[i]

            let prospectiveWidth = currentRowWidth + size.width + (currentRow.isEmpty ? 0 : spacing)
            if prospectiveWidth > bounds.width {
                if !currentRow.isEmpty {
                    rows.append(currentRow)
                    currentRow = []
                    currentRowWidth = 0
                }
            }
            
            if currentRow.isEmpty && size.width > bounds.width {
                rows.append([(i, size)])
            } else {
                currentRow.append((i, size))
                currentRowWidth += size.width + (currentRow.count == 1 ? 0 : spacing)
            }
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        var currentY = bounds.minY
        
        for row in rows {
            let rowWidth = row.map { $0.size.width }.reduce(0, +) + CGFloat(max(0, row.count - 1)) * spacing
            let maxRowHeight = row.map { $0.size.height }.max() ?? 0
            
            var currentX = bounds.minX + (bounds.width - rowWidth) / 2.0
            
            for item in row {
                let subview = subviews[item.index]
                let newProposal = ProposedViewSize(width: item.size.width, height: maxRowHeight)
                subview.place(at: CGPoint(x: currentX, y: currentY), anchor: .topLeading, proposal: newProposal)
                currentX += item.size.width + spacing
            }
            
            currentY += maxRowHeight + spacing
        }
    }
} 