import SwiftUI

// MARK: - Masonry Grid

struct MasonryGrid: View {
    let items: [DiscoverItem]

    var body: some View {
        let (left, right) = distributeItems(items)

        HStack(alignment: .top, spacing: 10) {
            // Left column
            LazyVStack(spacing: 10) {
                ForEach(left) { item in
                    DiscoverCard(item: item)
                }
            }

            // Right column
            LazyVStack(spacing: 10) {
                ForEach(right) { item in
                    DiscoverCard(item: item)
                }
            }
        }
    }

    private func distributeItems(_ items: [DiscoverItem]) -> ([DiscoverItem], [DiscoverItem]) {
        var left: [DiscoverItem] = []
        var right: [DiscoverItem] = []
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0

        for item in items {
            let h = cardHeight(item)
            if leftHeight <= rightHeight {
                left.append(item)
                leftHeight += h + 10
            } else {
                right.append(item)
                rightHeight += h + 10
            }
        }
        return (left, right)
    }

    private func cardHeight(_ item: DiscoverItem) -> CGFloat {
        switch item.size {
        case .small: return 180
        case .tall: return 280
        case .wide: return 180
        }
    }
}
