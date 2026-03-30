import SwiftUI

struct RecordingTabView: View {
    @Binding var tabBarOffset: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            RecordingView(tabBarOffset: $tabBarOffset)

            // Status bar mask
            Color.clear
                .frame(height: 0)
                .background(Color.clBackground.ignoresSafeArea(edges: .top))
                .allowsHitTesting(false)
        }
        .background(Color.clBackground)
        .navigationBarHidden(true)
    }
}
