import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool

    @State private var currentStep = 0
    @State private var handle = ""
    @State private var displayName = ""
    @State private var avatarHue: Double = 0.6
    @State private var occupation = ""
    @State private var experienceIndex = 0
    @State private var selectedCategories: Set<String> = []

    private let totalSteps = 5
    private let experienceOptions = ["1年未満", "1-3年", "3-5年", "5-10年", "10年以上"]
    private let categories = [
        "iOS", "Android", "Web", "AI/ML", "ゲーム",
        "デザイン", "インフラ", "セキュリティ", "データ", "その他",
    ]

    var body: some View {
        VStack(spacing: 0) {
            progressBar

            TabView(selection: $currentStep) {
                loginStep.tag(0)
                handleStep.tag(1)
                profileStep.tag(2)
                occupationStep.tag(3)
                categoryStep.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(duration: 0.35, bounce: 0.15), value: currentStep)
        }
        .background(Color.clBackground)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.clBorder)
                    .frame(height: 3)

                Rectangle()
                    .fill(Color.clAccent)
                    .frame(
                        width: geo.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps),
                        height: 3
                    )
                    .animation(.spring(duration: 0.35, bounce: 0.15), value: currentStep)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Step 1: Login

    private var loginStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("CreateLog")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Color.clAccent)

            Text("ログイン方法を選択")
                .font(.system(size: 17))
                .foregroundStyle(Color.clTextSecondary)

            VStack(spacing: 12) {
                loginButton(
                    label: "Sign in with Apple",
                    icon: "apple.logo",
                    foreground: .white,
                    background: .black
                )

                loginButton(
                    label: "Googleでログイン",
                    icon: "g.circle.fill",
                    foreground: Color.clTextPrimary,
                    background: .white,
                    borderColor: Color.clBorder
                )

                loginButton(
                    label: "GitHubでログイン",
                    icon: "chevron.left.forwardslash.chevron.right",
                    foreground: .white,
                    background: Color(red: 0.2, green: 0.2, blue: 0.2)
                )

                loginButton(
                    label: "メールでログイン",
                    icon: "envelope.fill",
                    foreground: Color.clTextPrimary,
                    background: Color.clSurfaceHigh
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func loginButton(
        label: String,
        icon: String,
        foreground: Color,
        background: Color,
        borderColor: Color? = nil
    ) -> some View {
        Button {
            HapticManager.light()
            withAnimation { currentStep = 1 }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(background)
                    .overlay {
                        if let borderColor {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(borderColor, lineWidth: 1)
                        }
                    }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Handle

    private var handleStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("@ハンドルを決めよう")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.clTextPrimary)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    Text("@")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.clTextTertiary)
                        .frame(width: 30)

                    TextField("handle_name", text: $handle)
                        .font(.system(size: 17))
                        .foregroundStyle(Color.clTextPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.clSurfaceHigh)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.clBorder, lineWidth: 1)
                        )
                )

                if !handle.isEmpty {
                    HStack(spacing: 6) {
                        if isHandleValid {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.clSuccess)
                            Text("利用可能です")
                                .foregroundStyle(Color.clSuccess)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.clError)
                            Text(handleErrorMessage)
                                .foregroundStyle(Color.clError)
                        }
                    }
                    .font(.system(size: 13))
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 24)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: handle)

            Spacer()

            primaryButton("次へ", isActive: isHandleValid) {
                currentStep = 2
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private var isHandleValid: Bool {
        let pattern = /^[a-zA-Z0-9_]{3,15}$/
        return handle.wholeMatch(of: pattern) != nil
    }

    private var handleErrorMessage: String {
        if handle.count < 3 || handle.count > 15 {
            return "3-15文字で入力してください"
        }
        return "英数字とアンダースコアのみ使用できます"
    }

    // MARK: - Step 3: Profile

    private var profileStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("プロフィール設定")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.clTextPrimary)

            Button {
                HapticManager.light()
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    avatarHue = Double.random(in: 0...1)
                }
            } label: {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hue: avatarHue, saturation: 0.3, brightness: 0.4),
                                Color(hue: avatarHue, saturation: 0.2, brightness: 0.25),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.6))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Text("タップして色を変更")
                .font(.system(size: 13))
                .foregroundStyle(Color.clTextTertiary)

            TextField("表示名", text: $displayName)
                .font(.system(size: 17))
                .foregroundStyle(Color.clTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.clSurfaceHigh)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.clBorder, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 10) {
                primaryButton("次へ", isActive: true) {
                    currentStep = 3
                }
                secondaryButton("スキップ") {
                    currentStep = 3
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Step 4: Occupation

    private var occupationStep: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("職業・経験")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)

                Text("スキップ可能")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.clTextTertiary)
            }

            VStack(spacing: 14) {
                TextField("職業（例: iOSエンジニア）", text: $occupation)
                    .font(.system(size: 17))
                    .foregroundStyle(Color.clTextPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.clSurfaceHigh)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.clBorder, lineWidth: 1)
                            )
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text("経験年数")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.clTextSecondary)

                    Picker("経験年数", selection: $experienceIndex) {
                        ForEach(0..<experienceOptions.count, id: \.self) { index in
                            Text(experienceOptions[index]).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 10) {
                primaryButton("次へ", isActive: true) {
                    currentStep = 4
                }
                secondaryButton("スキップ") {
                    currentStep = 4
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Step 5: Categories

    private var categoryStep: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("興味のあるカテゴリを選んでね")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                    .multilineTextAlignment(.center)

                Text("3つ以上推奨")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.clTextTertiary)
            }

            categoryGrid
                .padding(.horizontal, 24)

            Spacer()

            primaryButton("はじめる", isActive: true) {
                HapticManager.success()
                isPresented = false
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ],
            spacing: 10
        ) {
            ForEach(categories, id: \.self) { category in
                let isSelected = selectedCategories.contains(category)

                Button {
                    HapticManager.light()
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        if isSelected {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .transition(.scale.combined(with: .opacity))
                        }
                        Text(category)
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(isSelected ? .white : Color.clTextPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? Color.clAccent : Color.clSurfaceHigh)
                            .overlay {
                                if !isSelected {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.clBorder, lineWidth: 1)
                                }
                            }
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Shared Buttons

    private func primaryButton(
        _ label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard isActive else { return }
            HapticManager.light()
            withAnimation { action() }
        } label: {
            Text(label)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.clAccent.opacity(isActive ? 1 : 0.4))
                )
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isActive)
    }

    private func secondaryButton(
        _ label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.light()
            withAnimation { action() }
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.clTextTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.plain)
    }
}
