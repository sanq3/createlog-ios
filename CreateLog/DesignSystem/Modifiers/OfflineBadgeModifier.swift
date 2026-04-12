import SwiftUI

/// オフライン時に画面上部へ「オフライン」バッジを表示する `ViewModifier`。
///
/// `networkMonitor.observe()` を subscribe し、疎通状態の変化に
/// spring 0.35 / bounce 0.15 で追従する。Liquid Glass (`.ultraThinMaterial`) 準拠。
///
/// ## 使い方
/// ```swift
/// MainTabView()
///     .offlineBadge(networkMonitor: dependencies.networkMonitor)
/// ```
///
/// ## 備考
/// - `networkMonitor` は引数注入 (Environment 越し取得より test で差し替えやすい)。
/// - タブバー干渉回避のため top edge に配置 (X / Instagram のオフラインバナー踏襲)。
struct OfflineBadgeModifier: ViewModifier {
    let networkMonitor: any NetworkMonitorProtocol
    @State private var isOffline = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isOffline {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 12, weight: .medium))
                        Text("オフライン")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.clTextPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.clTextPrimary.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .task {
                for await reachable in networkMonitor.observe() {
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        isOffline = !reachable
                    }
                }
            }
    }
}

extension View {
    /// オフライン時にバッジを画面上部に表示する。
    func offlineBadge(networkMonitor: any NetworkMonitorProtocol) -> some View {
        modifier(OfflineBadgeModifier(networkMonitor: networkMonitor))
    }
}
