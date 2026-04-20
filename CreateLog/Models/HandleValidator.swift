import Foundation
import OSLog

/// 予約済 handle チェッカ。
///
/// Bundle 内 `ReservedHandles.json` (canonical、`docs/reserved-handles.md` 参照) を起動時 1 回ロードし、
/// signup / handle 変更時に case-insensitive + stripped match (`_`, `.`, `-` 除去) で照合する。
///
/// **真のソースは DB** (Supabase migration の `profiles.handle` CHECK 制約)。
/// このクライアント validation は UX layer (入力中の即時フィードバック)。
/// 攻撃経路問わず DB レベルで拒否される設計を前提に、ここは補助。
enum HandleValidator {
    private static let logger = Logger(subsystem: "com.sanq3.createlog", category: "HandleValidator")

    /// 起動時に 1 回だけ lazy load される reserved set (全て lowercase)。
    private static let reservedSet: Set<String> = {
        guard let url = Bundle.main.url(forResource: "ReservedHandles", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([String].self, from: data) else {
            logger.error("ReservedHandles.json not found or invalid. Reserved-handle guard disabled (DB still enforces).")
            return []
        }
        logger.info("ReservedHandles loaded: \(list.count, privacy: .public) entries")
        return Set(list.map { $0.lowercased() })
    }()

    /// handle が予約語か判定する。
    /// - case-insensitive (lowercase で比較)
    /// - stripped match: `_` / `.` / `-` を除去した文字列も照合 (`a_d_m_i_n` → "admin" に一致で拒否)
    static func isReserved(_ handle: String) -> Bool {
        let trimmed = handle.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return false }

        if reservedSet.contains(trimmed) { return true }

        // stripped (区切り文字除去) でも照合
        let stripped = trimmed.filter { !"_.-".contains($0) }
        if stripped != trimmed, reservedSet.contains(stripped) { return true }

        return false
    }

    #if DEBUG
    /// test 用: reserved set 読み込み件数
    static var loadedCount: Int { reservedSet.count }
    #endif
}
