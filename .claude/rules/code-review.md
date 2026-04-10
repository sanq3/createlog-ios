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
