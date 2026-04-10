import SwiftUI

extension SDProject {
    /// プロジェクト名のハッシュからダークトーンのアイコン色を生成。
    /// MockData の Tempo/FocusFlow/DevBoard と同系統 (ダークネイビー〜ダークパープル)。
    var iconColor: Color {
        let palette: [(Double, Double, Double)] = [
            (0.20, 0.25, 0.45),  // ダークネイビー (Tempo 風)
            (0.25, 0.15, 0.35),  // ダークパープル (FocusFlow 風)
            (0.15, 0.20, 0.32),  // ダークブルーグレー (DevBoard 風)
            (0.18, 0.28, 0.25),  // ダークティール
            (0.28, 0.18, 0.22),  // ダークローズ
            (0.22, 0.22, 0.35),  // ダークスレート
        ]

        let hash = abs(name.hashValue)
        let index = hash % palette.count
        let (r, g, b) = palette[index]
        return Color(red: r, green: g, blue: b)
    }

    /// アイコンに表示する頭文字。
    var iconInitial: String {
        String(name.prefix(1))
    }
}
