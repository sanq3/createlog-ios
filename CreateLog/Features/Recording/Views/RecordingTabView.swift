import SwiftUI

struct RecordingTabView: View {
    @Bindable var viewModel: RecordingViewModel
    @Binding var tabBarOffset: CGFloat

    var body: some View {
        RecordingView(viewModel: viewModel, tabBarOffset: $tabBarOffset)
            .background(Color.clBackground)
    }
}
