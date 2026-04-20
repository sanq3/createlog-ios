import Testing
@testable import CreateLog

/// HandleValidator の挙動テスト。canonical `ReservedHandles.json` (557 語) を Bundle から実ロード。
/// - case-insensitive 照合
/// - stripped match (`_.-` 除去版)
/// - 通常 handle は拒否されない (grandfathering 境界)
@Suite("HandleValidator")
struct HandleValidatorTests {

    @Test("canonical JSON が bundle から 557+ 語ロードされる")
    func reservedListLoaded() {
        #if DEBUG
        #expect(HandleValidator.loadedCount >= 500, "canonical JSON がロードされていない、または語彙数が想定以下")
        #endif
    }

    @Test("典型的なシステム予約語は reserved", arguments: [
        "admin", "api", "auth", "login", "signup", "logout", "settings",
        "post", "posts", "feed", "explore", "discover", "notifications",
        "privacy", "terms", "support", "about", "help", "legal",
    ])
    func systemReservedWords(word: String) {
        #expect(HandleValidator.isReserved(word), "\(word) は reserved であるべき")
    }

    @Test("ブランド予約語は reserved", arguments: [
        "createlog", "tsukurog", "つくろぐ", "official", "staff", "team",
    ])
    func brandReservedWords(word: String) {
        #expect(HandleValidator.isReserved(word), "\(word) はブランド予約で reserved であるべき")
    }

    @Test("大文字小文字違いでも reserved 判定 (case-insensitive)", arguments: [
        "Admin", "ADMIN", "AdMiN", "POST", "Settings", "ABOUT",
    ])
    func caseInsensitive(word: String) {
        #expect(HandleValidator.isReserved(word), "\(word) は case-insensitive で reserved 判定されるべき")
    }

    @Test("stripped match: 区切り文字 (_ . -) 除去版でも照合", arguments: [
        "a_d_m_i_n",   // admin
        "a.d.m.i.n",   // admin
        "a-d-m-i-n",   // admin
        "s_e_t_t_i_n_g_s",
        "p.o.s.t",
    ])
    func strippedMatch(word: String) {
        #expect(HandleValidator.isReserved(word), "\(word) は stripped match で reserved 判定されるべき")
    }

    @Test("通常の handle は reserved ではない", arguments: [
        "sanq3", "john", "alice", "dev_engineer", "tsukuru_log_fan",
        "ios2026", "myhandle", "test_user_123",
    ])
    func nonReservedWords(word: String) {
        #expect(!HandleValidator.isReserved(word), "\(word) は通常 handle、reserved であってはならない")
    }

    @Test("空文字と空白は reserved ではない (validation は上流 regex が弾く)")
    func emptyAndWhitespace() {
        #expect(!HandleValidator.isReserved(""))
        #expect(!HandleValidator.isReserved("   "))
    }

    @Test("RFC 2142 / DNS well-known も reserved", arguments: [
        "hostmaster", "postmaster", "abuse", "noreply", "webmaster", "www",
    ])
    func rfc2142Reserved(word: String) {
        #expect(HandleValidator.isReserved(word), "\(word) は RFC 2142 / DNS で reserved であるべき")
    }
}
