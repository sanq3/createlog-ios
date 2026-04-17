import SwiftUI

/// Step 05: 技術スタック選択 (言語 + フレームワーク、複数選択)。
/// 選択済みプラットフォームに応じて表示項目をフィルタ。
struct OnboardingTechStackStep: View {
    @Binding var selectedStack: Set<String>
    let selectedPlatforms: Set<String>
    let onAdvance: () -> Void

    @State private var appeared = false
    @State private var chipsAppeared = false

    // MARK: - Platform → Tech マッピング

    /// 常に表示する技術
    private static let universalLanguages: Set<String> = [
        "JavaScript", "TypeScript", "Python", "Java", "Go", "Rust", "C++", "C#", "Dart",
    ]
    private static let universalFrameworks: Set<String> = [
        "React", "React Native", "Flutter", "Unity",
    ]

    /// Platform 固有の技術
    private static let platformLanguages: [String: [String]] = [
        "iOS": ["Swift"],
        "Android": ["Kotlin"],
        "Web": ["Ruby", "PHP"],
        "Desktop": [],
    ]
    private static let platformFrameworks: [String: [String]] = [
        "iOS": ["SwiftUI"],
        "Android": [],
        "Web": ["Next.js", "Vue", "Angular", "Django", "Rails", "Laravel", "Spring Boot"],
        "Desktop": [],
    ]

    private struct Section {
        let title: String
        let items: [String]
    }

    private var filteredSections: [Section] {
        var langs = Self.universalLanguages
        var fws = Self.universalFrameworks

        for platform in selectedPlatforms {
            if let extra = Self.platformLanguages[platform] {
                langs.formUnion(extra)
            }
            if let extra = Self.platformFrameworks[platform] {
                fws.formUnion(extra)
            }
        }

        // その他 / Desktop → 全部表示
        if selectedPlatforms.contains("その他") || selectedPlatforms.isEmpty {
            for values in Self.platformLanguages.values { langs.formUnion(values) }
            for values in Self.platformFrameworks.values { fws.formUnion(values) }
        }

        // 順序を固定 (全候補リストの順に並べる)
        let langOrder = ["Swift", "Kotlin", "JavaScript", "TypeScript", "Python",
                         "Java", "Go", "Rust", "C++", "C#", "Ruby", "PHP", "Dart"]
        let fwOrder = ["React", "Next.js", "Vue", "Angular",
                       "Flutter", "React Native", "SwiftUI",
                       "Django", "Rails", "Laravel", "Spring Boot", "Unity"]

        return [
            Section(title: "onboarding.tech.languages", items: langOrder.filter { langs.contains($0) }),
            Section(title: "onboarding.tech.frameworks", items: fwOrder.filter { fws.contains($0) }),
        ]
    }

    private var canAdvance: Bool { !selectedStack.isEmpty }

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 90)

                Text("onboarding.tech.title")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                    .tracking(-0.5)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                Spacer().frame(height: 20)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        ForEach(filteredSections, id: \.title) { section in
                            sectionView(section)
                        }

                        HStack(spacing: 10) {
                            specialChip("その他")
                            specialChip("まだ決めていない")
                        }
                        .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 16)
                }

                Spacer().frame(height: 8)

                OnboardingPrimaryCTA(
                    title: "common.continue",
                    isEnabled: canAdvance,
                    disabledStyle: .dimmed,
                    action: onAdvance
                )
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.15)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(duration: 0.7, bounce: 0.2)) {
                    chipsAppeared = true
                }
            }
        }
    }

    // MARK: - Section

    private func sectionView(_ section: Section) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(section.title))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.clTextPrimary.opacity(0.4))
                .tracking(1)
                .textCase(.uppercase)
                .padding(.horizontal, 36)

            let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(section.items.enumerated()), id: \.offset) { index, item in
                    chip(item, globalIndex: index)
                }
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Chips

    private func chip(_ item: String, globalIndex: Int) -> some View {
        let selected = selectedStack.contains(item)
        return Button {
            HapticManager.selection()
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                if selected {
                    selectedStack.remove(item)
                } else {
                    if selectedStack.contains("まだ決めていない") {
                        selectedStack.remove("まだ決めていない")
                    }
                    selectedStack.insert(item)
                }
            }
        } label: {
            Text(LocalizedStringKey(item))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? Color.clBackground : Color.clTextPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    Capsule().fill(selected ? Color.clTextPrimary : Color.clSurfaceHigh)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(selected ? Color.clear : Color.clTextPrimary.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .opacity(chipsAppeared ? 1 : 0)
        .offset(y: chipsAppeared ? 0 : 12)
        .animation(
            .spring(duration: 0.5, bounce: 0.2).delay(Double(globalIndex) * 0.02),
            value: chipsAppeared
        )
    }

    private func specialChip(_ item: String) -> some View {
        let selected = selectedStack.contains(item)
        return Button {
            HapticManager.selection()
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                if selected {
                    selectedStack.remove(item)
                } else {
                    if item == "まだ決めていない" {
                        selectedStack.removeAll()
                    }
                    selectedStack.insert(item)
                }
            }
        } label: {
            Text(LocalizedStringKey(item))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? Color.clBackground : Color.clTextPrimary.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    Capsule().fill(selected ? Color.clTextPrimary : Color.clSurfaceHigh)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(selected ? Color.clear : Color.clTextPrimary.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .opacity(chipsAppeared ? 1 : 0)
    }
}

#Preview {
    OnboardingTechStackStep(
        selectedStack: .constant(["Swift", "SwiftUI"]),
        selectedPlatforms: ["iOS"],
        onAdvance: {}
    )
}
