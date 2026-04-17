import SwiftUI

// MARK: - Report

enum ReportReason: String, CaseIterable, Identifiable {
    case spam = "スパム"
    case inappropriate = "不適切なコンテンツ"
    case harassment = "ハラスメント"
    case copyright = "著作権侵害"
    case impersonation = "なりすまし"
    case other = "common.other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .spam: "exclamationmark.bubble"
        case .inappropriate: "eye.slash"
        case .harassment: "hand.raised"
        case .copyright: "doc.text"
        case .impersonation: "person.crop.circle.badge.exclamationmark"
        case .other: "ellipsis.circle"
        }
    }
}

struct ReportSheet: View {
    let targetName: String
    let onSubmit: (ReportReason, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: ReportReason?
    @State private var detail = ""
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    submittedView
                } else {
                    formView
                }
            }
            .background(Color.clBackground)
            .navigationTitle("report.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.clTextSecondary)
                }
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("「\(targetName)」を報告する理由を選択してください")
                        .font(.clBody)
                        .foregroundStyle(Color.clTextSecondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    VStack(spacing: 0) {
                        ForEach(ReportReason.allCases) { reason in
                            reasonRow(reason)
                        }
                    }
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    if selectedReason == .other {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("recording.detail.optional")
                                .font(.clCaption)
                                .foregroundStyle(Color.clTextTertiary)

                            TextField("report.detail.input", text: $detail, axis: .vertical)
                                .font(.clBody)
                                .lineLimit(3...6)
                                .padding(12)
                                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .scrollIndicators(.hidden)

            submitButton
                .padding(20)
        }
    }

    private func reasonRow(_ reason: ReportReason) -> some View {
        let isSelected = selectedReason == reason
        let isLast = reason == ReportReason.allCases.last

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                    selectedReason = reason
                }
                HapticManager.selection()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: reason.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? Color.clAccent : Color.clTextTertiary)
                        .frame(width: 24)

                    Text(reason.rawValue)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.clTextPrimary)

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? Color.clAccent : Color.clBorder)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if !isLast {
                Rectangle()
                    .fill(Color.clBorder)
                    .frame(height: 0.5)
                    .padding(.leading, 54)
            }
        }
    }

    private var submitButton: some View {
        Button {
            guard let reason = selectedReason else { return }
            HapticManager.success()
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                submitted = true
            }
            onSubmit(reason, detail)
        } label: {
            Text("report.submit")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    selectedReason != nil ? Color.clError : Color.clTextTertiary,
                    in: .capsule
                )
        }
        .buttonStyle(.bounce)
        .disabled(selectedReason == nil)
    }

    // MARK: - Submitted

    private var submittedView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.clSuccess)

            Text("report.received")
                .font(.clTitle)
                .foregroundStyle(Color.clTextPrimary)

            Text("内容を確認の上、対応いたします。\nご協力ありがとうございます。")
                .font(.clBody)
                .foregroundStyle(Color.clTextSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("common.close")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.clAccent, in: .capsule)
            }
            .buttonStyle(.bounce)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Block Confirmation

struct BlockConfirmSheet: View {
    let userName: String
    let userHandle: String
    let onBlock: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.clError.opacity(0.1))
                        .frame(width: 80, height: 80)
                    Image(systemName: "nosign")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Color.clError)
                }

                // Text
                VStack(spacing: 8) {
                    Text("@\(userHandle) をブロック")
                        .font(.clTitle)
                        .foregroundStyle(Color.clTextPrimary)

                    Text("profile.block.description")
                        .font(.clBody)
                        .foregroundStyle(Color.clTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        HapticManager.medium()
                        onBlock()
                        dismiss()
                    } label: {
                        Text("profile.block")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.clError, in: .capsule)
                    }
                    .buttonStyle(.bounce)

                    Button {
                        dismiss()
                    } label: {
                        Text("common.cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.clTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.clBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.clTextTertiary)
                    }
                }
            }
        }
    }
}
