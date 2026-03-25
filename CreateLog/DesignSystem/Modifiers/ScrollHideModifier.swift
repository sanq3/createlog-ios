import SwiftUI

struct ScrollHideModifier: ViewModifier {
    let headerHeight: CGFloat
    @Binding var headerOffset: CGFloat
    @Binding var tabBarOffset: CGFloat
    @State private var currentScrollOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { oldValue, newValue in
                let delta = newValue - oldValue
                currentScrollOffset = newValue
                guard newValue > 0 else {
                    headerOffset = 0
                    tabBarOffset = 0
                    return
                }
                headerOffset = min(0, max(-headerHeight, headerOffset - delta))
                tabBarOffset = min(90, max(0, tabBarOffset + delta))
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                if newPhase == .idle && oldPhase != .idle {
                    withAnimation(.easeOut(duration: 0.25)) {
                        if currentScrollOffset <= 0 {
                            headerOffset = 0
                            tabBarOffset = 0
                        } else {
                            headerOffset = -headerHeight
                            tabBarOffset = 90
                        }
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
