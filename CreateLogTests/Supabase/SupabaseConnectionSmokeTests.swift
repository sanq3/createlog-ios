import Testing
import Foundation
@testable import CreateLog

/// Supabase 接続の smoke test。
///
/// T2 (2026-04-12): xcconfig → Info.plist → `Bundle.main.infoDictionary` 経路での設定値注入が
/// 正しく動作することを確認する。**実ネットワーク疎通は行わない** (CI fragile 回避、
/// 実疎通は T8 統合 smoke test or 手動 simulator 確認で行う)。
///
/// このテストは:
/// - **user が xcconfig に anon key を入力した後** に全て pass する
/// - **stub 状態 (xcconfig 未設定 or プレースホルダ)** ではいくつか fail するのは期待動作
/// - fail すれば「xcconfig 値を入れて」と気付ける安全網
///
/// 前提条件:
/// 1. `Config/Debug.xcconfig` に `SUPABASE_URL` と `SUPABASE_ANON_KEY` が設定済
/// 2. `project.yml` の `info.properties` で `SUPABASE_URL: $(SUPABASE_URL)` が注入済 (L22-23)
/// 3. `xcodegen generate` 後にビルド
@Suite("Supabase Connection Smoke")
struct SupabaseConnectionSmokeTests {

    // MARK: - Info.plist 経路

    /// Info.plist に SUPABASE_URL が埋め込まれていることを確認。
    /// xcconfig 未設定だと `$(SUPABASE_URL)` がそのまま入るか、`unconfigured.supabase.co` fallback。
    @Test("Info.plist に SUPABASE_URL が存在する")
    func testSupabaseURLInfoPlist() {
        let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String
        #expect(urlString != nil, "SUPABASE_URL が Info.plist に無い。project.yml の info.properties を確認")
    }

    /// Info.plist に SUPABASE_ANON_KEY が埋め込まれていることを確認。
    @Test("Info.plist に SUPABASE_ANON_KEY が存在する")
    func testSupabaseAnonKeyInfoPlist() {
        let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String
        #expect(anonKey != nil, "SUPABASE_ANON_KEY が Info.plist に無い。project.yml の info.properties を確認")
    }

    // MARK: - 値の妥当性

    /// SUPABASE_URL が dummy fallback (`unconfigured.supabase.co`) でないこと。
    /// fail する場合: xcconfig に `SUPABASE_URL = https://aeycoojfugzzuvrpfjhj.supabase.co` を追加
    @Test("SUPABASE_URL が dummy fallback でない")
    func testSupabaseURLIsNotDummy() {
        let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
        #expect(
            !urlString.contains("unconfigured.supabase.co"),
            "xcconfig が未設定。Config/Debug.xcconfig に SUPABASE_URL を追加してください"
        )
        #expect(
            !urlString.contains("$("),
            "xcconfig 値が未展開 ($(SUPABASE_URL) のまま)。xcodegen generate 後に rebuild"
        )
    }

    /// SUPABASE_URL が本プロジェクトの project ref を含むこと。
    /// project ref は固定: `aeycoojfugzzuvrpfjhj`
    @Test("SUPABASE_URL が期待する project ref を含む")
    func testSupabaseURLMatchesProjectRef() {
        let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
        // 未設定時は skip (dummy fallback は別 test で catch)
        guard !urlString.isEmpty, !urlString.contains("unconfigured") else { return }
        #expect(
            urlString.contains("aeycoojfugzzuvrpfjhj"),
            "SUPABASE_URL の project ref が一致しません。期待値: aeycoojfugzzuvrpfjhj"
        )
    }

    /// SUPABASE_ANON_KEY が空でない + dummy でないこと。
    @Test("SUPABASE_ANON_KEY が空でない")
    func testSupabaseAnonKeyIsNotEmpty() {
        let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
        #expect(!anonKey.isEmpty, "SUPABASE_ANON_KEY が空。Config/Debug.xcconfig に設定してください")
        #expect(
            anonKey != "dummy-key-unconfigured",
            "SUPABASE_ANON_KEY が dummy fallback。xcconfig 値が正しく注入されているか確認"
        )
        #expect(
            !anonKey.contains("$("),
            "SUPABASE_ANON_KEY が未展開。xcodegen generate 後に rebuild"
        )
    }

    // MARK: - SupabaseClientFactory のインスタンス化

    /// SupabaseClientFactory.shared が crash せずインスタンス化できること。
    /// (設定値に関係なく、dummy fallback 経路でも SupabaseClient 自体は生成される)
    @Test("SupabaseClientFactory.shared がインスタンス化成功")
    func testSupabaseClientFactoryInstantiation() {
        // SupabaseClient は nonnull、アクセスで crash しない
        let client = SupabaseClientFactory.shared
        // compile-time で non-nil が保証されているので assertion は type check のみ
        _ = client
    }
}
