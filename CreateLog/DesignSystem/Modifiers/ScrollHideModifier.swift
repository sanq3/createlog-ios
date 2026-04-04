import SwiftUI

struct ScrollHideModifier: ViewModifier {
    let headerHeight: CGFloat
    let tabBarHeight: CGFloat = 100
    let headerSnapDuration: CGFloat
    @Binding var headerOffset: CGFloat
    @Binding var tabBarOffset: CGFloat

    @State private var currentScrollOffset: CGFloat = 0
    @State private var lastDelta: CGFloat = 0
    @State private var isSnappingHeader = false

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
                lastDelta = delta

                // Tab bar always tracks 1:1
                tabBarOffset = min(tabBarHeight, max(0, tabBarOffset + delta))

                // Header tracks 1:1 only when not snapping
                if !isSnappingHeader {
                    headerOffset = min(0, max(-headerHeight, headerOffset - delta))
                }
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

                let tabBarHiddenRatio = tabBarOffset / tabBarHeight
                let shouldHide = tabBarHiddenRatio > 0.1

                withAnimation(.spring(duration: 0.2, bounce: 0)) {
                    if shouldHide {
                        tabBarOffset = tabBarHeight
                    } else {
                        tabBarOffset = 0
                    }
                }
                isSnappingHeader = true
                withAnimation(.spring(duration: headerSnapDuration, bounce: 0)) {
                    if shouldHide {
                        headerOffset = -headerHeight
                    } else {
                        headerOffset = 0
                    }
                }
                Task {
                    try? await Task.sleep(for: .seconds(headerSnapDuration))
                    isSnappingHeader = false
                }
            }
    }
}

extension View {
    func scrollHide(
        headerHeight: CGFloat,
        headerOffset: Binding<CGFloat>,
        tabBarOffset: Binding<CGFloat>,
        headerSnapDuration: CGFloat = 0.2
    ) -> some View {
        modifier(ScrollHideModifier(
            headerHeight: headerHeight,
            headerSnapDuration: headerSnapDuration,
            headerOffset: headerOffset,
            tabBarOffset: tabBarOffset
        ))
    }
}
