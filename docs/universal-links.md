# Universal Links — 設計・検証 checklist

## 設計 (確定事項、2026-04-20)

### URL 形式

prefix なし handle URL (GitHub/Zenn/Qiita 踏襲):

- `https://createlog.app/{handle}` — プロフィール (例: `https://createlog.app/sanq3`)
- `https://createlog.app/post/{uuid}` — 投稿詳細
- `https://createlog.app/` — LP (Universal Links 対象外、Web only)
- `https://createlog.app/privacy` `/terms` `/support` `/en/*` — Web only

handle の reserved list は 557 語 (`docs/reserved-handles.md`、canonical は `CreateLog/Resources/ReservedHandles.json`)。Web page path と衝突しないよう signup 時に弾く。

### コンポーネント

| レイヤー | ファイル | 役割 |
|---|---|---|
| iOS entitlements | `project.yml` → `CreateLog.entitlements` | `applinks:createlog.app` + `applinks:www.createlog.app` (apex + www 両方必須) |
| iOS URL 受信 | `CreateLogApp.swift:115` `.onContinueUserActivity("NSUserActivityTypeBrowseWeb")` | Universal Links (cold start 含む) を `DeepLinkHandler` に流す |
| iOS URL scheme | `CreateLogApp.swift` `.onOpenURL` | `createlog://...` の legacy URL scheme も同 handler で受ける |
| iOS パース | `DeepLinkHandler.swift` | `https://createlog.app/...` host 判定 + regex validation |
| Web AASA | `createlog-web/public/.well-known/apple-app-site-association` | Team ID `YP9R79UAU5` + Bundle ID `com.sanq3.createlog` + `components` + legacy `paths` 併記 |
| Web header | `createlog-web/public/_headers` | AASA に `Content-Type: application/json` を強制 |
| Web fallback | `createlog-web/src/pages/404.astro` | アプリ未インストール時の handle/post 判定 + App Store CTA + 自動起動試行 |
| Web smart banner | `createlog-web/src/layouts/Layout.astro:73` | `apple-itunes-app` meta、`app-argument` に canonical Universal Link |

### 落とし穴 (10 年運用、業界標準調査由来)

1. **apex + www 両方登録必須**: `applinks:createlog.app` のみだと `www.createlog.app` のリンクは UL 発火しない
2. **AASA に redirect 禁止**: 301/302 で返ると Apple swcd が fetch 拒否。apex ↔ www の redirect も `/.well-known/` 以外にのみ適用
3. **Apple CDN 24h キャッシュ**: `https://app-site-association.cdn-apple.com/a/v1/{domain}` に prefetch + 24h キャッシュされる。launch 直前の AASA 変更は反映されない → **App Store 審査中に確定**
4. **Safari URL バー直接入力は UL 発火しない**: Apple が意図的に同一ドメインからの遷移を UL 対象外にしている (無限ループ防止)。検証時は Notes / Messages / 別ドメインから開く
5. **App Store ID placeholder は絶対 commit 禁止**: `id000000000` は App Store で 404 を返す → UX 崩壊。iTunes Search API で取得した実 ID (`6755903579`) を hardcode

## 実機検証 checklist

Simulator では Universal Links は動かない (Apple 公式制約、`swcd` が AASA fetch しない)。必ず実機で検証する。

### 前提

- TestFlight 配信済 or Xcode run で実機 install 済
- Web deploy 済 (`createlog-web` が `https://createlog.app/` で配信されている)
- 実機が iOS 26+
- Apple CDN に AASA が prefetch 済 (deploy 後 5 分〜数時間)

### Step 1: AASA 配信確認

**Mac から:**

```bash
# apex
curl -I https://createlog.app/.well-known/apple-app-site-association
# 期待: HTTP/2 200、Content-Type: application/json、redirect なし

# www
curl -I https://www.createlog.app/.well-known/apple-app-site-association
# 期待: 同上

# 内容
curl -s https://createlog.app/.well-known/apple-app-site-association | jq .

# Apple CDN (これが 200 返すまで実機では動かない)
curl -s https://app-site-association.cdn-apple.com/a/v1/createlog.app | jq .
```

### Step 2: 実機で Notes 長押し テスト (最重要)

1. 実機 Notes アプリ起動
2. 新規 note に `https://createlog.app/sanq3` を入力 (任意の実在 handle、無い場合は 404 page 動作確認になる)
3. URL を **長押し**
4. Context menu に **「CreateLog で開く」** が表示されることを確認
5. タップ → アプリが起動し、そのまま `sanq3` プロフィール画面に遷移

`https://createlog.app/post/<実在 post UUID>` でも同手順。

### Step 3: Messages 経由テスト

1. 自分に iMessage で `https://createlog.app/sanq3` を送信
2. Messages アプリでリンクをタップ
3. アプリが起動してプロフィール画面に遷移

### Step 4: 別ドメインからのリンクテスト (重要)

**Safari URL バー直接入力は UL 発火しない。別ドメイン経由が必須。**

1. Google 検索で適当に検索 → 検索結果ページで Safari URL バーに `javascript:void(0); window.location='https://createlog.app/sanq3'` を入力 (または gist/pastebin に link 貼って踏む)
2. アプリが起動してプロフィール画面に遷移
3. Safari が開いた場合は **Universal Links 失敗** (AASA 未反映 or entitlements 漏れ)

### Step 5: ログ確認 (Step 2-4 が失敗した場合)

Mac の Console.app を起動:

1. 左サイドバー → iPhone 実機を選択
2. Filter: `process:swcd` (Shared Web Credentials Daemon)
3. 実機で Universal Links 試行 → ログ流れる
4. キーワード検索: `applinks`, `createlog.app`, `ApplicationAssociationEntitlement`

期待ログパターン:

- `[applinks] Finished retrieving associated domain data for createlog.app` → AASA fetch 成功
- `[applinks] Failed to retrieve associated domain data ...` → AASA 配信に問題
- `[applinks] No matching applications for URL ...` → AASA の paths / components にマッチしない
- `[applinks] Associated domain data timed out` → CDN reachability 問題

### Step 6: 失敗時の fresh fetch

AASA キャッシュが古い場合:

- アプリを **削除 → 再 install** (最も確実)
- 実機の「設定 → Developer → Associated Domains Development」で該当 domain を再評価 (Xcode run の dev build のみ有効)

### Step 7: Smart banner テスト (未インストール端末)

1. **別の実機** または **シミュレータ Safari** (Simulator でも Safari は smart banner を表示する)
2. `https://createlog.app/sanq3` を Safari で開く
3. 画面上部に **CreateLog smart banner** が表示 (アプリアイコン + "Install" CTA)
4. Install → App Store → `id6755903579` が開く

未インストール端末で Install した後、AASA が有効になれば Step 2 の挙動になる。

## トラブルシュート

| 症状 | 原因 | 対処 |
|---|---|---|
| Notes 長押しに "CreateLog で開く" が出ない | AASA fetch 失敗 | Step 1 の curl で AASA 配信確認 → Apple CDN 確認 → アプリ再 install |
| Safari URL バー入力で UL 発火しない | Apple 仕様 (同一ドメイン) | Step 4 の別ドメイン経由で確認 |
| AASA 変更が反映されない | Apple CDN 24h キャッシュ | 24h 待つ or アプリ削除 → 再 install |
| 一部 path だけ UL 発火しない | AASA components の exclude/include 順序 | components は順に評価、exclude を上に置く |
| dev build (Xcode run) で UL 動かず release では動く | dev build は Associated Domains Development 設定が必要 | 設定 → Developer → AD Dev で domain を再評価 |

## 関連

- iOS 実装詳細: `CreateLog/App/DeepLinkHandler.swift`, `CreateLog/App/CreateLogApp.swift`
- Web 実装詳細: `createlog-web/public/.well-known/apple-app-site-association`, `createlog-web/src/pages/404.astro`
- Reserved handles: `docs/reserved-handles.md`
- Apple docs: https://developer.apple.com/documentation/xcode/supporting-associated-domains
