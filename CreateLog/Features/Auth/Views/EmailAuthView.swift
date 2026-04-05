import SwiftUI

/// メールアドレス認証画面
struct EmailAuthView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    var body: some View {
        VStack(spacing: 24) {
            // Toggle Sign In / Sign Up
            Picker("", selection: $viewModel.isSignUpMode) {
                Text("ログイン").tag(false)
                Text("新規登録").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            VStack(spacing: 16) {
                // Email
                VStack(alignment: .leading, spacing: 6) {
                    Text("メールアドレス")
                        .font(.caption)
                        .foregroundStyle(Color.clTextSecondary)

                    TextField("example@email.com", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .email)
                        .padding(12)
                        .background(Color.clSurfaceLow)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Password
                VStack(alignment: .leading, spacing: 6) {
                    Text("パスワード")
                        .font(.caption)
                        .foregroundStyle(Color.clTextSecondary)

                    SecureField("8文字以上", text: $viewModel.password)
                        .textContentType(viewModel.isSignUpMode ? .newPassword : .password)
                        .focused($focusedField, equals: .password)
                        .padding(12)
                        .background(Color.clSurfaceLow)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal)

            // Error
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Submit Button
            Button {
                focusedField = nil
                Task {
                    await viewModel.signInWithEmail()
                }
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(Color.clBackground)
                    } else {
                        Text(viewModel.isSignUpMode ? "アカウントを作成" : "ログイン")
                    }
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.clBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.clTextPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(viewModel.isLoading)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 16)
        .background(Color.clBackground)
        .navigationTitle(viewModel.isSignUpMode ? "新規登録" : "ログイン")
        .navigationBarTitleDisplayMode(.inline)
    }
}
