import SwiftUI

struct ProfileView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Avatar & info
                VStack(spacing: 8) {
                    AvatarView(initials: "S", size: 72, status: .online)

                    Text("San")
                        .font(.clTitle)
                        .foregroundStyle(Color.clTextPrimary)

                    Text("@san_dev")
                        .font(.clCaption)
                        .foregroundStyle(Color.clTextTertiary)

                    Text("iOS / Web エンジニア")
                        .font(.clBody)
                        .foregroundStyle(Color.clTextSecondary)

                    // Stats row
                    HStack(spacing: 24) {
                        profileStat(value: "120", label: "フォロワー")
                        profileStat(value: "85", label: "フォロー")
                        profileStat(value: "1,240h", label: "累計")
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 16)

                // Mini chart
                WeeklyChart(data: MockData.weeklyHours)
                    .padding(.horizontal, 20)

                // My apps
                VStack(alignment: .leading, spacing: 12) {
                    Text("マイアプリ")
                        .font(.clHeadline)
                        .foregroundStyle(Color.clTextSecondary)
                        .padding(.horizontal, 20)

                    appCard(name: "つくろぐ", desc: "エンジニアの記録プラットフォーム")
                    appCard(name: "FocusFlow", desc: "ポモドーロタイマー")
                }

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.clBackground)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticManager.light()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Color.clTextSecondary)
                }
            }
        }
    }

    private func profileStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.clHeadline)
                .foregroundStyle(Color.clTextPrimary)
                .tabularNumbers()
            Text(label)
                .font(.clCaption)
                .foregroundStyle(Color.clTextTertiary)
        }
    }

    private func appCard(name: String, desc: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [Color.clSurfaceHigh, Color.clSurfaceLow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.clHeadline)
                    .foregroundStyle(Color.clTextPrimary)
                Text(desc)
                    .font(.clCaption)
                    .foregroundStyle(Color.clTextTertiary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.clBorder, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}
