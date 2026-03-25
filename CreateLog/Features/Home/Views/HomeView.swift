import SwiftUI

struct HomeView: View {
    @State private var segmentIndex = 0
    @State private var posts = MockData.posts
    @Binding var tabBarOffset: CGFloat

    @State private var headerOffset: CGFloat = 0
    private let headerHeight: CGFloat = 120

    var body: some View {
        ZStack(alignment: .top) {
            // Layer 1: Feed
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(posts.enumerated()), id: \.element.id) { _, post in
                        PostCardView(post: post)
                    }
                }
                .padding(.top, headerHeight + 12)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            .scrollHide(headerHeight: headerHeight, headerOffset: $headerOffset, tabBarOffset: $tabBarOffset)

            // Layer 2: Header（上にスライドしてステータスバーマスクの裏に隠れる）
            headerView
                .offset(y: headerOffset)

            // Layer 3: ステータスバーマスク（最前面、常に白）
            Color.clear
                .frame(height: 0)
                .background(Color.clBackground.ignoresSafeArea(edges: .top))
                .allowsHitTesting(false)
        }
        .background(Color.clBackground)
        .navigationBarHidden(true)
    }

    private var headerView: some View {
        VStack(spacing: 10) {
            CLSegmentedControl(
                items: ["タイムライン", "フォロー中"],
                selection: $segmentIndex
            )
            .padding(.horizontal, 20)

            Button {
                HapticManager.light()
            } label: {
                HStack(spacing: 12) {
                    HStack(spacing: -8) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hue: Double(i) * 0.3, saturation: 0.25, brightness: 0.55),
                                            Color(hue: Double(i) * 0.3, saturation: 0.2, brightness: 0.4)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 28, height: 28)
                                .overlay(Circle().strokeBorder(Color.clBackground, lineWidth: 2))
                        }
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("3人が今作業中")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.clTextPrimary)
                        Text("タップして確認")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    Spacer()

                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.clSuccess)
                            .frame(width: 6, height: 6)
                            .modifier(PulseModifier())
                        Text("LIVE")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color.clSuccess)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.clSuccess.opacity(0.12))
                            .overlay(Capsule().strokeBorder(Color.clSuccess.opacity(0.25), lineWidth: 1))
                    )
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.clSurfaceLow)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.clBorder, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.clBackground)
    }
}
