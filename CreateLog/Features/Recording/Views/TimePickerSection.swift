import SwiftUI

struct TimePickerSection: View {
    @Bindable var viewModel: RecordingViewModel

    @State private var showConfirmation = false

    private var pickerTotal: Int {
        viewModel.pickerHours * 60 + viewModel.pickerMinutes
    }

    private var hasSelection: Bool {
        viewModel.selectedTag != nil
    }

    var body: some View {
        VStack(spacing: 12) {
            DurationPicker(hours: $viewModel.pickerHours, minutes: $viewModel.pickerMinutes)
                .frame(height: 100)

            // Selected tag + record button
            HStack(spacing: 10) {
                if let tag = viewModel.selectedTag {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(RecordingViewModel.colorForTag(tag))
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
                                .fill(pickerTotal > 0 ? Color.clAccent : Color.clBorder)
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

    private var canSave: Bool {
        pickerTotal > 0
    }

    private func save() {
        guard canSave else { return }
        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
            showConfirmation = true
        }
        viewModel.savePickerTime()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                showConfirmation = false
            }
        }
    }

    private var confirmationOverlay: some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.clSuccess)
            Text("記録しました")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.clTextPrimary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}
