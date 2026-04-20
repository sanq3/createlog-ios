# Reserved Handles — 単一ソースと 3 箇所同期ルール

## 目的

`https://createlog.app/{handle}` prefix なし handle URL の衝突を防ぐため、システム予約語 / URL path / ブランド / RFC 2142 / offensive terms を弾く。

## 真のソース (canonical)

**iOS リポジトリ内の 1 ファイルが canonical。Web / DB はここから派生同期。**

```
createlog-ios/CreateLog/Resources/ReservedHandles.json
```

総計 **557 語** (v1、2026-04-20)。内訳:

- `marteinn/The-Big-Username-Blocklist` main/list.txt (~542 語) — Privileges / Code / Terms / Financial / Sections / Actions
- つくろぐブランド (6 語): `createlog`, `tsukurog`, `つくろぐ`, `official`, `staff`, `team`
- URL path (38 語): `post`, `feed`, `home`, `explore`, `discover`, `notifications`, `settings`, `account`, `profile`, `admin`, `about`, `help`, `api`, `app`, `blog`, `docs`, `changelog`, `pricing`, `community`, `press`, `contact`, `legal`, `privacy`, `terms`, `support`, `en`, `ja`, `_astro`, 他
- インフラ (6 語): `supabase`, `auth`, `oauth`, `storage`, `realtime`, `rpc`

## 3 箇所の同期先

| 場所 | ファイル | 役割 |
|---|---|---|
| iOS | `createlog-ios/CreateLog/Resources/ReservedHandles.json` (canonical) | signup / handle 変更時 validation (UX layer) |
| Web | `createlog-web/src/data/reserved-handles.json` | 404.astro の RESERVED set、Web 側の handle URL 衝突防止 |
| DB | `supabase/migrations/YYYYMMDDHHMMSS_handle_citext_reserved.sql` の CHECK 制約正規表現 | 真のソース (攻撃経路問わず DB レベルで拒否) |

## 同期ルール

**変更頻度**: 年 1-2 回想定 (新機能追加で URL path 予約、ブランド拡張)。

**変更手順 (毎回必ず 3 箇所全部更新、片方漏れ NG):**
1. iOS `ReservedHandles.json` を編集 (canonical)
2. Web `reserved-handles.json` に copy (`cp createlog-ios/.../ReservedHandles.json createlog-web/src/data/reserved-handles.json`)
3. Supabase migration 新規作成 (新規語を含む CHECK 制約に update、既存 handle は grandfathered)
4. この docs の「総計」「内訳」を update

**自動化の余地** (v2.1 以降):
- monorepo 化すれば symlink で同期可能
- 現状は別リポなので CI hook or weekly script で sync check

## 照合ロジック (実装規約)

全 platform で以下を統一:

- **case-insensitive**: 入力を `lowercase()` してから `RESERVED` set で contains 確認
- **stripped match**: `_`, `.`, `-` を削除した正規化文字列でも照合 (例: `a_d_m_i_n` → `admin` に一致 → 拒否)
- **regex match 前に適用**: handle 形式 regex (`^[a-zA-Z][a-zA-Z0-9_]{2,14}$`) より先に reserved check
- **grandfathered**: reserved 追加時、既存登録ユーザーはそのまま使える (DB CHECK は新規 INSERT/UPDATE のみ)

## Offensive filter (別 layer)

成人向け / 差別語 filter は reserved list に混ぜない (業界標準)。v2.1 で `obscenity` 相当のライブラリを別途導入予定。
