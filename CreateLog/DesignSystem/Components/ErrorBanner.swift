import SwiftUI

/// エラーメッセージを画面上部に表示するバナー。
/// 記号禁止ルール (feedback_no_symbols_in_ui.md) 準拠で SF Symbols を使わず、
/// タイポグラフィと shape (左縦線) のみで構成する。
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Color.clError)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text("common.error")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.clError)
                    .textCase(.uppercase)
                    .kerning(0.5)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.clTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("common.close") {
                onDismiss()
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.clTextSecondary)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.trailing, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.clError.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
    }
}

// MARK: - ViewModifier

/// errorMessage バインディングを受け取り、上部バナーで表示する ViewModifier。
/// 使用: `.errorBanner($viewModel.errorMessage)`
struct ErrorBannerModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let msg = message {
                    ErrorBanner(message: msg) {
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            message = nil
                        }
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.15), value: message)
    }
}

extension View {
    func errorBanner(_ message: Binding<String?>) -> some View {
        modifier(ErrorBannerModifier(message: message))
    }
}
