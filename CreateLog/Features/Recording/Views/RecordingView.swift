import SwiftUI

struct RecordingView: View {
    @State private var isRecording = false
    @State private var elapsedSeconds = 0
    @State private var timer: Timer?

    var timeString: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Timer
                VStack(spacing: 8) {
                    Text(timeString)
                        .font(.clTimer)
                        .foregroundStyle(Color.clTextPrimary)
                        .tabularNumbers()
                        .contentTransition(.numericText())

                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 12))
                        Text("iOS開発")
                            .font(.clCaption)
                    }
                    .foregroundStyle(Color.clTextTertiary)

                    Button {
                        withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                            isRecording.toggle()
                        }
                        isRecording ? HapticManager.medium() : HapticManager.success()
                        toggleTimer()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    isRecording
                                        ? Color.clError.opacity(0.15)
                                        : Color.clAccent.opacity(0.15)
                                )
                                .frame(width: 64, height: 64)

                            if isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.clError)
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.clAccent)
                                    .offset(x: 2)
                            }
                        }
                        .shadow(
                            color: isRecording
                                ? Color.clError.opacity(0.2)
                                : Color.clAccent.opacity(0.2),
                            radius: 12
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.top, 20)

                // VS Code status
                GlassCard {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.clSuccess)
                            .frame(width: 8, height: 8)
                            .shadow(color: Color.clSuccess.opacity(0.5), radius: 4)

                        Text("VS Codeで記録中")
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextSecondary)

                        Spacer()

                        Text("2h 15m")
                            .font(.clHeadline)
                            .foregroundStyle(Color.clTextPrimary)
                            .tabularNumbers()
                    }
                }
                .padding(.horizontal, 20)

                // Today's records
                VStack(alignment: .leading, spacing: 12) {
                    Text("今日の記録")
                        .font(.clHeadline)
                        .foregroundStyle(Color.clTextSecondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        recordRow(icon: "chevron.left.forwardslash.chevron.right", name: "UI実装", time: "2h 30m")
                        Divider().overlay(Color.clBorder)
                        recordRow(icon: "ladybug", name: "バグ修正", time: "45m")
                        Divider().overlay(Color.clBorder)
                        recordRow(icon: "book", name: "Swift学習", time: "1h 15m")
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func recordRow(icon: String, name: String, time: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.clTextTertiary)
                .frame(width: 24)

            Text(name)
                .font(.clBody)
                .foregroundStyle(Color.clTextPrimary)

            Spacer()

            Text(time)
                .font(.clHeadline)
                .foregroundStyle(Color.clTextSecondary)
                .tabularNumbers()
        }
        .padding(.vertical, 12)
    }

    private func toggleTimer() {
        if isRecording {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                elapsedSeconds += 1
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }
}
