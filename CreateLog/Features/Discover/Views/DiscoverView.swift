import SwiftUI

// MARK: - Discover View

struct DiscoverView: View {
    @Environment(\.dependencies) private var deps
    @State private var searchText = ""
    #if DEBUG
    @State private var discoverItems: [DiscoverItem] = MockData.discoverItems
    #else
    @State private var discoverItems: [DiscoverItem] = []
    #endif
    @Binding var tabBarOffset: CGFloat
    let reselectCount: Int

    @State private var scrollPosition: ScrollPosition = .init(edge: .top)
    @State private var isRefreshing = false
    @State private var isAtTop = true
    @State private var headerOffset: CGFloat = 0
    private let headerHeight: CGFloat = 56

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                if isRefreshing {
                    ProgressView()
                        .padding(.top, headerHeight + 16)
                }

                MasonryGrid(items: discoverItems)
                    .padding(.horizontal, 12)
                    .padding(.top, headerHeight + 8)
                    .padding(.bottom, 100)
            }
            .scrollPosition($scrollPosition)
            .scrollIndicators(.hidden)
            .scrollHide(headerHeight: headerHeight, headerOffset: $headerOffset, tabBarOffset: $tabBarOffset)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, newValue in
                isAtTop = newValue <= 5
            }

            searchHeader
                .offset(y: headerOffset)

        }
        .background(Color.clBackground)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: reselectCount) {
            if isAtTop {
                isRefreshing = true
                HapticManager.light()
                Task {
                    try? await Task.sleep(for: .milliseconds(1500))
                    isRefreshing = false
                }
            } else {
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    scrollPosition.scrollTo(edge: .top)
                    headerOffset = 0
                    tabBarOffset = 0
                }
                HapticManager.light()
            }
        }
    }

    private var headerContentOpacity: Double {
        headerHeight > 0 ? 1.0 + Double(headerOffset / headerHeight) : 1.0
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.clTextTertiary)

            Text("ユーザー、タグ、プロジェクトを検索")
                .font(.clBody)
                .foregroundStyle(Color.clTextTertiary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .opacity(headerContentOpacity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}
