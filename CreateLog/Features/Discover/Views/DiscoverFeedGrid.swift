import SwiftUI

/// Discover 用 2 列 masonry grid。FeedItem (Post / Project) 配列を
/// 累積高さが短い方のカラムに次のタイルを積んでいくシンプルなアルゴリズムで振り分ける。
/// Instagram Explore / Pinterest の旧来手法と同等 (順序は維持しつつ高さを均す)。
struct DiscoverFeedGrid: View {
    let items: [FeedItem]
    /// 末尾タイルが表示された時に呼ばれる (無限スクロール用)。
    var onReachEnd: (() -> Void)? = nil

    var body: some View {
        let columns = distribute(items)

        HStack(alignment: .top, spacing: 10) {
            LazyVStack(spacing: 10) {
                ForEach(columns.left) { item in
                    DiscoverFeedCard(item: item)
                        .onAppear { triggerEndIfNeeded(item: item) }
                }
            }

            LazyVStack(spacing: 10) {
                ForEach(columns.right) { item in
                    DiscoverFeedCard(item: item)
                        .onAppear { triggerEndIfNeeded(item: item) }
                }
            }
        }
    }

    private struct MasonryColumns {
        var left: [FeedItem]
        var right: [FeedItem]
    }

    private func distribute(_ items: [FeedItem]) -> MasonryColumns {
        var columns = MasonryColumns(left: [], right: [])
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0
        let spacing: CGFloat = 10

        for item in items {
            let h = item.masonrySize.height
            if leftHeight <= rightHeight {
                columns.left.append(item)
                leftHeight += h + spacing
            } else {
                columns.right.append(item)
                rightHeight += h + spacing
            }
        }
        return columns
    }

    private func triggerEndIfNeeded(item: FeedItem) {
        guard let onReachEnd else { return }
        // 末尾から prefetchThreshold 件以内で発火
        guard let lastIndex = items.lastIndex(where: { $0.id == item.id }) else { return }
        if lastIndex >= max(0, items.count - AppConfig.prefetchThreshold) {
            onReachEnd()
        }
    }
}
