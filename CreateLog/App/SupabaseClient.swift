import Foundation
import Supabase
import OSLog

enum SupabaseClientFactory {
    private static let logger = Logger(subsystem: "com.sanq3.createlog", category: "SupabaseClient")

    /// Supabase Auth session を iOS Keychain に保存するための storage オプション。
    /// サービス名を明示して他アプリの default service と衝突しないようにする。
    /// iOS では SDK のデフォルトも KeychainLocalStorage だが、依存関係と意図を
    /// 一目で分かるようにここで明示する (security.md 準拠)。
    private static let authOptions = SupabaseClientOptions.AuthOptions(
        storage: KeychainLocalStorage(service: "com.sanq3.createlog.auth")
    )

    /// 本番用SupabaseClient。
    /// xcconfig (SUPABASE_URL / SUPABASE_ANON_KEY) が未設定の場合は
    /// ダミークライアントを返す (SwiftUI Preview/CI環境でのクラッシュ回避)。
    /// ダミークライアントで実際のネットワーク呼び出しを行うとエラーになる。
    static let shared: SupabaseClient = {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: urlString),
              let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !anonKey.isEmpty
        else {
            logger.warning("SUPABASE_URL / SUPABASE_ANON_KEY not configured. Returning dummy client (network calls will fail).")
            return SupabaseClient(
                supabaseURL: URL(string: "https://unconfigured.supabase.co")!,
                supabaseKey: "dummy-key-unconfigured",
                options: SupabaseClientOptions(auth: authOptions)
            )
        }

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(auth: authOptions)
        )
    }()
}
