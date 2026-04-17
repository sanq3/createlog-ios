import SwiftUI

/// 初回ログイン後のハンドル設定画面
struct HandleSetupView: View {
    @State private var handle = ""
    @State private var isChecking = false
    @State private var isAvailable: Bool?
    @State private var errorMessage: String?

    @Environment(\.dependencies) private var dependencies

    let onComplete: (String) -> Void

    private var isValid: Bool {
        handle.count >= 3 && handle.count <= 15 && isAvailable == true
    }

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 8) {
                Text("auth.handle.setup.title")
                    .font(.title2.bold())
                    .foregroundStyle(Color.clTextPrimary)

                Text("auth.handle.setup.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(Color.clTextSecondary)
            }
            .padding(.top, 40)

            // Input
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("@")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Color.clTextSecondary)

                    TextField("username", text: $handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.title3)
                        .onChange(of: handle) { _, newValue in
                            let sanitized = sanitize(newValue)
                            if sanitized != newValue { handle = sanitized }
                            isAvailable = nil
                            errorMessage = nil
                        }
                }
                .padding(12)
                .background(Color.clSurfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Status
                HStack(spacing: 6) {
                    if isChecking {
                        ProgressView()
                            .controlSize(.small)
                        Text("auth.handle.checking")
                            .font(.caption)
                            .foregroundStyle(Color.clTextSecondary)
                    } else if let available = isAvailable {
                        // 記号の代わりに色付きの円 shape を使う
                        Circle()
                            .fill(available ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(available ? "onboarding.handle.available" : "onboarding.handle.taken")
                            .font(.caption)
                            .foregroundStyle(available ? .green : .red)
                    } else if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("onboarding.handle.rule")
                            .font(.caption)
                            .foregroundStyle(Color.clTextTertiary)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 24)

            // Check Button
            Button {
                Task { await checkAvailability() }
            } label: {
                Text("auth.handle.check")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.clTextPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.clSurfaceHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(handle.count < 3 || isChecking)

            Spacer()

            // Continue
            Button {
                onComplete(handle)
            } label: {
                Text("common.continue")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.clBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isValid ? AnyShapeStyle(Color.clTextPrimary) : AnyShapeStyle(Color.clTextTertiary))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isValid)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color.clBackground)
    }

    // MARK: - Logic

    private func sanitize(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let filtered = input.unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(filtered))
        return String(result.prefix(15))
    }

    private func checkAvailability() async {
        let trimmed = handle.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else {
            errorMessage = "3文字以上入力してください"
            return
        }

        isChecking = true
        defer { isChecking = false }

        do {
            isAvailable = try await dependencies.profileRepository.checkHandleAvailability(trimmed)
        } catch {
            errorMessage = "確認に失敗しました"
        }
    }
}
