import SwiftUI

struct TabItem: Identifiable {
    let id: Int
    let icon: String
    let iconFill: String
    let label: String
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var namespace

    private let tabs: [TabItem] = [
        TabItem(id: 0, icon: "house", iconFill: "house.fill", label: "ホーム"),
        TabItem(id: 1, icon: "magnifyingglass", iconFill: "magnifyingglass", label: "発見"),
        TabItem(id: 2, icon: "circle.dotted.and.circle", iconFill: "circle.dotted.and.circle", label: "記録"),
        TabItem(id: 3, icon: "bell", iconFill: "bell.fill", label: "通知"),
        TabItem(id: 4, icon: "person", iconFill: "person.fill", label: "マイ"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab.id,
                    namespace: namespace
                ) {
                    guard selectedTab != tab.id else { return }
                    withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                        selectedTab = tab.id
                    }
                    HapticManager.light()
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.clBackground)
                .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(Color.clBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

struct TabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // Trigger press animation
            withAnimation(.spring(duration: 0.15)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
                    isPressed = false
                }
            }
            action()
        }) {
            VStack(spacing: 6) {
                Image(systemName: isSelected ? tab.iconFill : tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .light))
                    .foregroundStyle(isSelected ? Color.clTextPrimary : Color.clTextTertiary)
                    .scaleEffect(isPressed ? 0.7 : 1.0)
                    .offset(y: isPressed ? 3 : 0)

                // Indicator dot
                Circle()
                    .fill(isSelected ? Color.clTextPrimary : Color.clear)
                    .frame(width: 5, height: 5)
                    .scaleEffect(isSelected ? 1.0 : 0.0)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
