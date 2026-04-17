import SwiftUI

struct TabItem: Identifiable {
    let id: Int
    let icon: String
    let iconFill: String
    let label: LocalizedStringKey
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    var onReselect: ((Int) -> Void)?

    private let tabs: [TabItem] = [
        TabItem(id: 0, icon: "house", iconFill: "house.fill", label: "tab.home"),
        TabItem(id: 1, icon: "magnifyingglass", iconFill: "magnifyingglass", label: "tab.discover"),
        TabItem(id: 2, icon: "circle.dotted.and.circle", iconFill: "circle.dotted.and.circle", label: "tab.record"),
        TabItem(id: 3, icon: "chart.bar", iconFill: "chart.bar.fill", label: "tab.report"),
        TabItem(id: 4, icon: "person", iconFill: "person.fill", label: "tab.profile"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.clBorder)

            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    Button {
                        if selectedTab == tab.id {
                            onReselect?(tab.id)
                        } else {
                            withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                                selectedTab = tab.id
                            }
                        }
                        HapticManager.light()
                    } label: {
                        Image(systemName: selectedTab == tab.id ? tab.iconFill : tab.icon)
                            .font(.system(size: 20, weight: selectedTab == tab.id ? .semibold : .light))
                            .foregroundStyle(
                                selectedTab == tab.id
                                    ? Color.clTextPrimary
                                    : Color.clTextSecondary
                            )
                            .symbolEffect(.bounce, value: selectedTab == tab.id)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .accessibilityLabel(Text(tab.label))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color.clBackground)
    }
}
