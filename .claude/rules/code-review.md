---
description: コード変更時のレビュー基準とチェックリスト
globs: ["**/*.swift"]
---

# Code Review Standards

## レビュートリガー

以下の変更後は必ずレビューする:

- コード追加・変更後
- 認証・課金・ユーザーデータに関わるコード変更
- アーキテクチャ変更
- PR マージ前

## レビューチェックリスト

- [ ] 関数は50行以下
- [ ] ファイルは200行以下（超えたら分割検討）
- [ ] ネスト4階層以下
- [ ] エラーハンドリングが明示的
- [ ] 機密情報がハードコードされていない
- [ ] print / debugPrint が残っていない
- [ ] 新機能にテストがある

## セキュリティ（iOS固有）

**swift-reviewer エージェントを使え:**

- 認証・認可コード
- Supabase クエリ
- Keychain 操作
- StoreKit 課金処理
- ユーザー入力処理
- ディープリンク処理

**検出すべき問題:**

- 機密情報のハードコード（API key, secret, Supabase service_role key）
- UserDefaults への認証情報保存（Keychain 必須）
- RLS なしの Supabase テーブルアクセス
- xcconfig 外の環境依存値
- ATS 例外の不必要な追加
- Info.plist の過剰な権限要求

## 重大度

| Level | 意味 | アクション |
|-------|------|-----------|
| CRITICAL | セキュリティ脆弱性・データ損失リスク | **ブロック** - マージ前に必ず修正 |
| HIGH | バグ・重大な品質問題 | **警告** - マージ前に修正推奨 |
| MEDIUM | 保守性の懸念 | **情報** - 修正検討 |
| LOW | スタイル・軽微な提案 | **任意** |

## エージェント

| Agent | 用途 |
|-------|------|
| **swift-reviewer** | Swift/iOS コード品質、アーキテクチャ準拠、デザインシステム準拠、セキュリティ |
| **ios-planner** | 設計判断・影響範囲分析 |

## 承認基準

- **Approve**: CRITICAL/HIGH なし
- **Warning**: HIGH のみ（注意付きマージ可）
- **Block**: CRITICAL あり

## 誤検知を避けるためのチェック (レビュー時必読)

**UIUX を損なう削除提案を出す前に、以下を必ず確認しろ:**

### 1. Apple 純正 swipe API を「DragGesture 禁止ルール違反」と誤認するな

`.tabViewStyle(.page)` / `.swipeActions` / `NavigationStack` の edge swipe / `.scrollTargetBehavior(.paging)` は **Apple 純正 wrapper** であり、`architecture.md` の「DragGesture 禁止」ルールの対象外。削除提案を出す前に `architecture.md` の「Apple 純正 swipe API はこのルールの対象外」節を読め。

**判定フロー:**
1. コードが `DragGesture` / `simultaneousGesture` を直接使っているか? → YES なら違反候補
2. コードが `.tabViewStyle(.page)` 等の Apple 純正 wrapper か? → **違反ではない。削除提案するな**
3. 削除すると X / Instagram 踏襲 UX が失われるか? → YES なら業界標準違反。削除提案するな

### 2. UIUX を変える提案は必ずユーザー確認が必要

以下の変更は「削除してもコードは動く」でも UIUX 体験を変える:
- swipe / drag / 左右切替機能の削除
- アニメーション削除 / カスタマイズ削除
- gesture / haptic / transition の改変
- tab / page の構造変更

これらは**コード品質 HIGH ではなく UIUX 変更**として分類し、「提案」として出す。削除を前提にしてはいけない。

### 3. 「architecture.md 違反」と主張する前に該当節を原文で読め

ルール文言を抽象的に当てはめず、節の**由来**セクション (いつなぜ追加されたか) まで読んで真の対象を理解しろ。

**由来**: 2026-04-13 swift-reviewer が FollowListView の `.tabViewStyle(.page)` を HIGH 指摘した (誤検知)。`.page` は UIPageViewController wrapper であり X / Instagram と同じ業界標準実装。削除すれば UIUX 後退。レビュー精度を上げるため本節を追加。
