import SwiftUI

struct ScrollHideModifier: ViewModifier {
    let headerHeight: CGFloat
    let tabBarHeight: CGFloat = 90
    @Binding var headerOffset: CGFloat
    @Binding var tabBarOffset: CGFloat

    @State private var currentScrollOffset: CGFloat = 0

    // Noise filter: ignore deltas smaller than this
    private let noiseThreshold: CGFloat = 0.5

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { oldValue, newValue in
                let delta = newValue - oldValue
                currentScrollOffset = newValue

                // Top of content: always show
                guard newValue > 0 else {
                    headerOffset = 0
                    tabBarOffset = 0
                    return
                }

                guard abs(delta) > noiseThreshold else { return }

                // Always 1:1 tracking in both directions
                headerOffset = min(0, max(-headerHeight, headerOffset - delta))
                tabBarOffset = min(tabBarHeight, max(0, tabBarOffset + delta))
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                guard newPhase == .idle, oldPhase != .idle else { return }

                // At top: always show
                if currentScrollOffset <= 0 {
                    withAnimation(.spring(duration: 0.2, bounce: 0)) {
                        headerOffset = 0
                        tabBarOffset = 0
                    }
                    return
                }

                // 50% threshold snap
                let headerHiddenRatio = headerHeight > 0 ? abs(headerOffset) / headerHeight : 0
                let tabBarHiddenRatio = tabBarHeight > 0 ? tabBarOffset / tabBarHeight : 0
                let shouldHide = max(headerHiddenRatio, tabBarHiddenRatio) > 0.5

                withAnimation(.spring(duration: 0.2, bounce: 0)) {
                    if shouldHide {
                        headerOffset = -headerHeight
                        tabBarOffset = tabBarHeight
                    } else {
                        headerOffset = 0
                        tabBarOffset = 0
                    }
                }
            }
    }
}

extension View {
    func scrollHide(
        headerHeight: CGFloat,
        headerOffset: Binding<CGFloat>,
        tabBarOffset: Binding<CGFloat>
    ) -> some View {
        modifier(ScrollHideModifier(
            headerHeight: headerHeight,
            headerOffset: headerOffset,
            tabBarOffset: tabBarOffset
        ))
    }
}
