import SwiftUI

// MARK: - Discover View

struct DiscoverView: View {
    @State private var searchText = ""
    @Binding var tabBarOffset: CGFloat

    @State private var headerOffset: CGFloat = 0
    private let headerHeight: CGFloat = 56

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                MasonryGrid(items: MockData.discoverItems)
                    .padding(.horizontal, 12)
                    .padding(.top, headerHeight + 8)
                    .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .scrollHide(headerHeight: headerHeight, headerOffset: $headerOffset, tabBarOffset: $tabBarOffset)

            searchHeader
                .offset(y: headerOffset)

            Color.clear
                .frame(height: 0)
                .background(Color.clBackground.ignoresSafeArea(edges: .top))
                .allowsHitTesting(false)
        }
        .background(Color.clBackground)
        .navigationBarHidden(true)
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clSurfaceLow)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.clBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.clBackground)
    }
}
