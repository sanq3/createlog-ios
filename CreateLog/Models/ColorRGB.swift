import Foundation

/// RGB で色を保持する軽量構造体。
/// Foundation-only で SwiftUI 変換は DesignSystem/Extensions/ColorRGB+SwiftUI.swift に分離。
struct ColorRGB: Sendable {
    let red: Double
    let green: Double
    let blue: Double
}
