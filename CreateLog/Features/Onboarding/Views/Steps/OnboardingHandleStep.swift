import SwiftUI

/// Step 09: ハンドル選択。auth 成功後に `@username` を確定する。
/// - 3-15 文字、先頭英字、英数字 + `_` のみ
/// - 500ms debounce で一意性チェック
/// - 確定 → profiles.handle を update → onComplete
/// - あとで設定 → onSkip (handle 未設定のまま、profile 編集画面で後から設定可能)
struct OnboardingHandleStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false
    @State private var cardVisible = false
    @State private var ctaVisible = false
    @FocusState private var handleFocused: Bool

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 100)

                Text("ハンドルを決めよう")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                    .tracking(-0.5)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                Spacer().frame(height: 12)

                Text("プロフィール URL とメンションに使われます")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.clTextPrimary.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)

                Spacer().frame(height: 36)

                // Handle input card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Text("@")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.clTextPrimary.opacity(0.45))

                        TextField("username", text: Binding(
                            get: { viewModel.handleInput },
                            set: { viewModel.onHandleInputChanged($0) }
                        ))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.clTextPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.done)
                        .focused($handleFocused)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                        availabilityBadge
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.clSurfaceHigh)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: 1.5)
                    )

                    // Status message
                    if let message = statusMessage {
                        Text(message)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 4)
                            .lineLimit(2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        // 高さ確保でレイアウト揺れ防止
                        Text(" ")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .padding(.horizontal, 32)
                .opacity(cardVisible ? 1 : 0)
                .scaleEffect(cardVisible ? 1 : 0.95)

                Spacer()

                // Confirm error
                if let error = viewModel.handleConfirmError {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.clError)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 12)
                }

                // CTA buttons
                VStack(spacing: 12) {
                    // Confirm button
                    Button {
                        Task {
                            let success = await viewModel.confirmHandle()
                            if success {
                                HapticManager.light()
                                onComplete()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isConfirmingHandle {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.9)
                            }
                            Text(viewModel.isConfirmingHandle ? "保存中..." : "このハンドルで決定")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(viewModel.canConfirmHandle ? Color.clAccent : Color.clTextPrimary.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canConfirmHandle)
                    .padding(.horizontal, 32)

                    // Skip
                    Button {
                        HapticManager.light()
                        onSkip()
                    } label: {
                        Text("あとで設定する")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.clTextPrimary.opacity(0.4))
                    }
                    .padding(.top, 4)
                }
                .opacity(ctaVisible ? 1 : 0)
                .offset(y: ctaVisible ? 0 : 20)
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.1)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(duration: 0.7, bounce: 0.2)) {
                    cardVisible = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
                    ctaVisible = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                handleFocused = true
            }
        }
    }

    // MARK: - Availability badge

    @ViewBuilder
    private var availabilityBadge: some View {
        switch viewModel.handleAvailability {
        case .unknown:
            EmptyView()
        case .checking:
            ProgressView()
                .scaleEffect(0.7)
                .tint(Color.clTextPrimary.opacity(0.5))
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.clSuccess)
                .transition(.scale.combined(with: .opacity))
        case .taken, .error:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.clError)
                .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Derived UI state

    private var statusMessage: String? {
        if let validationError = viewModel.handleValidation.errorMessage {
            return validationError
        }
        switch viewModel.handleAvailability {
        case .available:
            return "このハンドルは使えます"
        case .taken:
            return "このハンドルは既に使われています"
        case .error(let message):
            return "確認エラー: \(message)"
        case .checking, .unknown:
            return nil
        }
    }

    private var statusColor: Color {
        if viewModel.handleValidation.errorMessage != nil {
            return Color.clError
        }
        switch viewModel.handleAvailability {
        case .available: return Color.clSuccess
        case .taken, .error: return Color.clError
        default: return Color.clTextPrimary.opacity(0.5)
        }
    }

    private var borderColor: Color {
        if viewModel.handleValidation.errorMessage != nil {
            return Color.clError.opacity(0.5)
        }
        switch viewModel.handleAvailability {
        case .available: return Color.clSuccess.opacity(0.5)
        case .taken, .error: return Color.clError.opacity(0.5)
        default: return Color.clTextPrimary.opacity(0.08)
        }
    }
}
