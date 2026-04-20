---
description: セキュリティ運用ルール。commit / log / secret 取り扱いの再発防止
globs: ["**/*.swift", "**/*.toml", "**/*.json", "**/*.md", "**/*.sql"]
---

# Security Rules

2026-04-21 制定。v2.0 リリース前 audit で発見した 4 種 incident の再発防止:
1. `supabase/.temp/pooler-url` 誤 commit (project ref + connection URL 公開)
2. `SupabaseAuthService` の `print` で `user.email` / `accessToken.len` log 流出
3. `.mcp.json` に project ref hardcode (template 化すべきだった)
4. `profile.occupation` カラムに i18n dot key 直書き保存

## 絶対禁止 (CRITICAL、commit 前に必ず block)

- **secret をリポにコミットするな** — anon key / service_role key / API token / password / JWT / private key
- **`supabase/.temp/` を git 管理するな** — pooler URL / connection string を含む、`.gitignore` 済
- **`*.xcconfig` / `.env*` を commit するな** — `.gitignore` 済
- **`.mcp.json` は project ref を含むため gitignore 済** — 共有する場合は `.mcp.json.example` に placeholder 化 (`YOUR_PROJECT_REF`) して template のみ commit
- **`print(...)` / `debugPrint(...)` で認証情報 / PII を出すな** — 下記詳細
- **service_role key をクライアントコードに含めるな** — anon key + RLS が唯一の正解

## print / Log 運用ルール

**全 production コード (CreateLog/**/*.swift) で `print` / `debugPrint` 禁止。**代わりに `os.Logger` を使う:

```swift
import OSLog
private static let logger = Logger(subsystem: "com.sanq3.createlog", category: "<Feature>")

// 認証 / session / user.id / user.email / token / error.localizedDescription は
// `privacy: .private` で redacted (production で自動マスク、debug 配信のみ展開可)
logger.info("sign in success (user.id=\(userId, privacy: .private))")
logger.error("auth failed: \(error.localizedDescription, privacy: .private)")

// 機能 label / step / provider 等の非 PII は privacy: .public で OK
logger.info("provider=\(provider, privacy: .public)")
```

**禁止例 (過去 incident):**
```swift
// ❌ PII leak: email が production の stderr / syslog / MDM から見える
print("sign in: email=\(session.user.email ?? "nil")")

// ❌ token length を出すのも attack surface を与える
print("accessToken.len=\(session.accessToken.count)")

// ❌ user.id を plain text で出すな (他ユーザー記録から逆引きされる)
print("userId=\(userId)")
```

## Deep link / URL scheme

- `DeepLink.parse(_:)` で必ず以下を validate:
  - `url.scheme` allowlist (`createlog` / `https` only、他 scheme は reject)
  - `url.absoluteString.count <= 512` (DoS 対策)
  - handle 等の parameter は **形式 regex で strict match** (3-15 char / 先頭 letter / 英数_ のみ等、domain の CHECK 制約と一致)
  - UUID parameter は `UUID(uuidString:)` で format 検証

## Supabase / RLS

- **全 public schema の table に RLS ENABLE 必須**。例外なし
- **SELECT policy は anon 不可視が default** — public 閲覧が意図されていない table は `TO authenticated` または `USING (auth.uid() IS NOT NULL)` で anon をブロック
- **UPDATE / DELETE policy は `USING` を必ず `auth.uid()` で縛る** — WITH CHECK 省略でも USING が new row にも適用されるが、owner 変更攻撃を防ぐため明示推奨
- **service_role は Edge Function 内でのみ使用**。クライアント app からは anon key + RLS 経由

## Secret Scan 自動化 (2026-04-21 導入)

**既に下記が有効化済み。迂回するな:**

- **Pre-commit hook** (`.git/hooks/pre-commit`): gitleaks で staged 差分 scan。detect → commit block
- **CI (GitHub Actions)** (`.github/workflows/secret-scan.yml`): push / PR 時に full history scan
- **設定**: `.gitleaks.toml` で project 固有 rule (supabase pooler URL / print-auth-token pattern) を定義
- **迂回**: `git commit --no-verify` は**禁止**。false positive は `.gitleaks.toml` の `[allowlist]` で明示 exception

## Secret rotate 手順 (DB password / anon key)

- DB password: Dashboard → Settings → Database → "Reset database password" (2026-04-20 に 1 回 rotate 済)
- anon key: Dashboard → Settings → API → "Reset service_role / anon key" (public 前提、通常 rotate 不要)
- rotate 後: password manager に保存、古い password を使う運用 tool (psql / migration script) は即更新

## 由来 (各 rule の incident 参照)

- **`supabase/.temp/` 禁止**: 2026-03-18 commit `87717a5` で `.temp/pooler-url` (postgres connection URL) が 3 週間 public leak
- **`print` PII 禁止**: 2026-04-20 audit で `SupabaseAuthService.signInWithApple` の print に email / accessToken.len / refreshToken.len が入っていると判明
- **`.mcp.json` gitignore**: 2026-04-20 redaction commit で template 化
- **RLS 全 table**: Phase 1 baseline audit 2026-04-11 で確認済、以降 migration 追加時に毎回 verify
