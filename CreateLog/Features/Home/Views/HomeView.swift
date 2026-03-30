import SwiftUI

struct HomeView: View {
    @Binding var tabBarOffset: CGFloat
    @Binding var showSideMenu: Bool
    @Binding var sideMenuDragOffset: CGFloat
    @State private var showCompose = false

    var body: some View {
        HomeContainerRepresentable(
            tabBarOffset: $tabBarOffset,
            showSideMenu: $showSideMenu,
            sideMenuDragOffset: $sideMenuDragOffset
        )
        .background(Color.clBackground)
        .overlay(alignment: .bottomTrailing) {
            Button {
                HapticManager.light()
                showCompose = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.clAccent, in: Circle())
                    .shadow(color: Color.clAccent.opacity(0.3), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 100)
            .offset(y: tabBarOffset)
        }
        .fullScreenCover(isPresented: $showCompose) {
            ComposeView()
        }
        .navigationBarHidden(true)
    }
}
