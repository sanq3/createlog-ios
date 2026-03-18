import SwiftUI

struct HomeView: View {
    @State private var segmentIndex = 0
    @State private var posts = MockData.posts

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    // Segment
                    CLSegmentedControl(
                        items: ["フォロー中", "おすすめ"],
                        selection: $segmentIndex
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    // Active now bar
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.clSuccess)
                            .frame(width: 8, height: 8)
                            .shadow(color: Color.clSuccess.opacity(0.5), radius: 4)
                            .modifier(PulseModifier())

                        Text("3人")
                            .font(.clCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.clTextPrimary)
                        + Text("が今作業中")
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextSecondary)

                        Spacer()

                        Image(systemName: "eye")
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.clBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                    // Feed
                    LazyVStack(spacing: 0) {
                        ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                            PostCardView(post: post)

                            if index < posts.count - 1 {
                                Divider()
                                    .overlay(Color.clBorder)
                                    .padding(.leading, 72)
                            }
                        }
                    }
                    .padding(.top, 6)

                    Spacer(minLength: 100)
                }
            }
            .scrollIndicators(.hidden)

            // FAB
            FloatingActionButton { }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
        }
        .background(Color.clBackground)
        .navigationTitle("つくろぐ")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticManager.light()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.clTextSecondary)
                }
            }
        }
    }
}

struct PulseModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.6 : 1.0)
            .scaleEffect(isAnimating ? 0.85 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}
