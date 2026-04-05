import SwiftUI

/// Step 04: 今日、どれだけやった？ 時間入力。
/// Wheel picker 2 本 (時 / 分) を全画面で大きく見せる。
/// 値が変わる度 haptic light + 数字を軽く scale pulse (1.0→1.02→1.0)。
/// 「続ける」は 0 でも押せる (スキップ許容、ただし保存はされる)。
struct OnboardingDurationStep: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    let onAdvance: () -> Void

    @State private var appeared = false
    @State private var pulseTick = 0

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 120)

                Text("今日、どれだけやった？")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                    .tracking(-0.5)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                Spacer()

                HStack(spacing: 24) {
                    pickerColumn(
                        label: "時間",
                        range: 0...12,
                        selection: $hours
                    )
                    pickerColumn(
                        label: "分",
                        range: 0...59,
                        selection: $minutes
                    )
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.94)

                Spacer()

                Button {
                    HapticManager.light()
                    onAdvance()
                } label: {
                    Text("続ける")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.clBackground)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 16)
                        .background(
                            Capsule().fill(Color.clTextPrimary)
                        )
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.15)) {
                appeared = true
            }
        }
    }

    private func pickerColumn(label: String, range: ClosedRange<Int>, selection: Binding<Int>) -> some View {
        VStack(spacing: 8) {
            Picker(label, selection: selection) {
                ForEach(range, id: \.self) { value in
                    Text("\(value)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.clTextPrimary)
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 100, height: 160)
            .onChange(of: selection.wrappedValue) { _, _ in
                HapticManager.light()
            }

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.clTextTertiary)
                .tracking(1)
        }
    }
}

#Preview {
    OnboardingDurationStep(
        hours: .constant(1),
        minutes: .constant(30),
        onAdvance: {}
    )
}
