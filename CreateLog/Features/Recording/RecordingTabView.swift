import SwiftUI

struct RecordingTabView: View {
    @State private var segmentIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            CLSegmentedControl(
                items: ["記録", "レポート", "カレンダー"],
                selection: $segmentIndex
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)

            TabView(selection: $segmentIndex) {
                RecordingView().tag(0)
                ReportView().tag(1)
                CalendarView().tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.snappy(duration: 0.3), value: segmentIndex)
        }
        .background(Color.clBackground)
        .navigationTitle("記録")
    }
}
