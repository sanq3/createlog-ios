import SwiftUI

struct RecordingTabView: View {
    @Binding var tabBarOffset: CGFloat

    var body: some View {
        RecordingView(tabBarOffset: $tabBarOffset)
            .background(Color.clBackground)
    }
}
