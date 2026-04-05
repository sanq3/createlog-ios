import SwiftUI

/// オンボーディング step 間の Headspace 流クロスフェード遷移。
/// 新 step 挿入時: offset y 16 → 0、opacity 0 → 1、blur 6 → 0
/// 旧 step 除去時: offset y -12 → 0、opacity 1 → 0、blur 0 → 4
/// 「別物が入れ替わった」ではなく「1 つのものが変化した」と認識させるための blur ブリッジ。
/// Linear onboarding の "cinematic transition" 原則を踏襲。
extension AnyTransition {
    static var onboardingStep: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: OnboardingStepTransitionModifier(progress: 0, phase: .insertion),
                identity: OnboardingStepTransitionModifier(progress: 1, phase: .insertion)
            ),
            removal: .modifier(
                active: OnboardingStepTransitionModifier(progress: 0, phase: .removal),
                identity: OnboardingStepTransitionModifier(progress: 1, phase: .removal)
            )
        )
    }
}

private struct OnboardingStepTransitionModifier: ViewModifier {
    let progress: Double
    let phase: Phase

    enum Phase {
        case insertion
        case removal
    }

    func body(content: Content) -> some View {
        let offsetY: CGFloat = phase == .insertion ? 16 : -12
        let maxBlur: CGFloat = phase == .insertion ? 6 : 4
        return content
            .opacity(progress)
            .offset(y: (1 - progress) * offsetY)
            .blur(radius: (1 - progress) * maxBlur)
    }
}
