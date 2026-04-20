import Foundation
import Supabase
import OSLog

enum SupabaseClientFactory {
    private static let logger = Logger(subsystem: "com.sanq3.createlog", category: "SupabaseClient")

    /// Supabase Auth session を iOS Keychain に保存するための storage オプション。
    /// サービス名を明示して他アプリの default service と衝突しないようにする。
    /// iOS では SDK のデフォルトも KeychainLocalStorage だが、依存関係と意図を
    /// 一目で分かるようにここで明示する (security.md 準拠)。
    ///
    /// `emitLocalSessionAsInitialSession: true` (2026-04-14):
    /// supabase-swift の next major で default 化される新挙動に opt-in。
    /// 旧挙動では起動時に stale session の refresh を試行して失敗すると session が
    /// 削除され、新規 Sign In と race condition で "Auth session missing" が発生していた
    /// (PR #822)。新挙動では local session を validity 問わず emit し、expired なら
    /// `session.isExpired` チェック or `.tokenRefreshed` event を待つ方式に変わる。
    private static let authOptions = SupabaseClientOptions.AuthOptions(
        storage: KeychainLocalStorage(service: "com.sanq3.createlog.auth"),
        emitLocalSessionAsInitialSession: true
    )

    /// SDK 内部 (Auth / Session / HTTP) の全挙動を OSLog に流すための diagnostic logger。
    /// Console.app / `xcrun simctl spawn ... log show --subsystem com.sanq3.createlog` で取得可能。
    /// session 書込み/読出し/削除、refresh、API call 全てが見える。
    /// 2026-04-14 "Auth session missing" 真因特定のため追加。
    private static let globalOptions = SupabaseClientOptions.GlobalOptions(
        logger: OSLogSupabaseLogger(
            Logger(subsystem: "com.sanq3.createlog", category: "SupabaseSDK")
        )
    )

    /// 本番用SupabaseClient。
    /// xcconfig (SUPABASE_URL / SUPABASE_ANON_KEY) が未設定の場合は
    /// ダミークライアントを返す (SwiftUI Preview/CI環境でのクラッシュ回避)。
    /// ダミークライアントで実際のネットワーク呼び出しを行うとエラーになる。
    static let shared: SupabaseClient = {
        // 2026-04-20 (security): print → os.Logger。SUPABASE_URL (project ref を含む) /
        // anonKey.count を平文 stdout に吐くと Console.app / MDM ツールから見えてしまうため、
        // privacy: .private で redacted。URL 設定の有無は bool だけ log する。
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        logger.debug("factory invoked (build=\(buildVersion, privacy: .public))")
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: urlString),
              let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !anonKey.isEmpty
        else {
            logger.error("DUMMY client — xcconfig not loaded. urlConfigured=\((Bundle.main.infoDictionary?["SUPABASE_URL"] as? String)?.isEmpty == false, privacy: .public) anonKeyPresent=\((Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String)?.isEmpty == false, privacy: .public)")
            return SupabaseClient(
                supabaseURL: URL(string: "https://unconfigured.supabase.co")!,
                supabaseKey: "dummy-key-unconfigured",
                options: SupabaseClientOptions(auth: authOptions, global: globalOptions)
            )
        }

        logger.info("real client configured (url=\(url.absoluteString, privacy: .private))")
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(auth: authOptions, global: globalOptions)
        )
    }()
}
