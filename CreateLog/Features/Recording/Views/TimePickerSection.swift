import SwiftUI

struct TimePickerSection: View {
    @Bindable var viewModel: RecordingViewModel

    @State private var showConfirmation = false

    private var pickerTotal: Int {
        viewModel.pickerHours * 60 + viewModel.pickerMinutes
    }

    private var tagColor: Color {
        if let tag = viewModel.selectedTag {
            return RecordingViewModel.colorForTag(tag)
        }
        return Color.clAccent
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let tag = viewModel.selectedTag {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(tagColor)
                            .frame(width: 3, height: 16)
                        Text(tag.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.clTextPrimary)
                            .lineLimit(1)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    Text("その他")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.clTextTertiary)
                }

                Spacer()

                Button {
                    save()
                } label: {
                    Text("記録")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(pickerTotal > 0 ? tagColor : Color.clBorder)
                        )
                }
                .buttonStyle(.bounce)
                .disabled(pickerTotal == 0)
            }
        }
        .overlay {
            if showConfirmation {
                confirmationOverlay
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.15), value: viewModel.selectedTag?.id)
    }

    private func save() {
        guard pickerTotal > 0 else { return }
        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
            showConfirmation = true
        }
        viewModel.savePickerTime()
        HapticManager.success()

        Task {
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                showConfirmation = false
            }
        }
    }

    private var confirmationOverlay: some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(tagColor)
            Text("記録しました")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.clTextPrimary)
        }
        .padding(20)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}
