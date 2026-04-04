import SwiftUI

struct TimeInputSheet: View {
    @Bindable var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var saved = false

    var body: some View {
        VStack(spacing: 20) {
            if let tag = viewModel.selectedTag {
                tagHeader(tag)
            }

            // Hour:Minute picker
            HStack(spacing: 0) {
                // Hours
                Picker("h", selection: $viewModel.pickerHours) {
                    ForEach(0..<13) { h in
                        Text("\(h) h").tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                // Minutes
                Picker("m", selection: $viewModel.pickerMinutes) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                        Text("\(m) m").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 150)

            // Record button
            Button {
                save()
            } label: {
                Text("記録する")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(pickerTotal > 0 ? Color.clAccent : Color.clBorder)
                    )
            }
            .buttonStyle(.bounce)
            .disabled(pickerTotal == 0)
        }
        .padding(20)
        .overlay {
            if saved {
                saveConfirmation
            }
        }
    }

    private var pickerTotal: Int {
        viewModel.pickerHours * 60 + viewModel.pickerMinutes
    }

    // MARK: - Header

    private func tagHeader(_ tag: SDProject) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(RecordingViewModel.colorForTag(tag))
                .frame(width: 4, height: 20)

            Text(tag.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.clTextPrimary)

            Spacer()

            Text(RecordingViewModel.formatDuration(pickerTotal))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.clTextTertiary)
        }
    }

    // MARK: - Save

    private func save() {
        guard pickerTotal > 0 else { return }
        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
            saved = true
        }
        viewModel.savePickerTime()

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            dismiss()
        }
    }

    private var saveConfirmation: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.clSuccess)

            Text(RecordingViewModel.formatDuration(pickerTotal))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.clTextPrimary)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}
