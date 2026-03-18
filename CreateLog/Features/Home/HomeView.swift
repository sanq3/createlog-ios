import SwiftUI

struct HomeView: View {
    @State private var segmentIndex = 0
    @State private var posts = MockData.posts

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CLSegmentedControl(
                    items: ["タイムライン", "フォロー中"],
                    selection: $segmentIndex
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)

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
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.clSurfaceLow)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.clBorder, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                LazyVStack(spacing: 12) {
                    ForEach(Array(posts.enumerated()), id: \.element.id) { _, post in
                        PostCardView(post: post)
                    }
                }
                .padding(.top, 12)

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.clBackground)
        .navigationBarHidden(true)
    }
}

struct PulseModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.4 : 1.0)
            .scaleEffect(isAnimating ? 0.7 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}
