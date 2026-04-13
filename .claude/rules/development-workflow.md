---
description: 機能実装ワークフロー (研究→計画→TDD→レビュー→コミット) とビルドコマンド
globs: ["**/*.swift"]
---

# Development Workflow

The Feature Implementation Workflow describes the development pipeline: research, planning, TDD, code review, and then committing to git.

## Feature Implementation Workflow

0. **Research & Reuse** _(mandatory before any new implementation)_
   - **GitHub code search first:** Run `gh search repos` and `gh search code` to find existing implementations, templates, and patterns before writing anything new.
   - **Library docs second:** Use Context7 or primary vendor docs to confirm API behavior, package usage, and version-specific details before implementing.
   - **Search for adaptable implementations:** Look for open-source projects that solve 80%+ of the problem and can be forked, ported, or wrapped.
   - Apple純正APIで代替できるなら純正を使え。SPM パッケージ導入前にメンテナンス状況を確認

1. **Plan First**
   - Use **ios-planner** agent to create implementation plan
   - Identify dependencies, risks, affected files
   - Break down into phases

2. **Implement**
   - Use **swift-implementer** agent (main tree 直接作業、worktree なし)
   - team-lead 自身も軽いタスクは直接実装する。orchestrator 専任にならない
   - 依存チェーン (例: T7a→T7b→T7c) は sequential で main tree 直接実行が最適
   - 独立タスクの並列実装のみ worktree isolation を検討 (Agent tool の isolation パラメータ)
   - 計画書に従って実装。計画外のことはやらない
   - テストを書く。80%+ coverage目標

3. **Code Review**
   - Use **swift-reviewer** agent immediately after writing code
   - Address CRITICAL and HIGH issues
   - Fix MEDIUM issues when possible

4. **Commit & Push**
   - Detailed commit messages
   - Follow conventional commits format

## Build Commands

### 自動ビルド: accumulator + Stop パターン

コード変更時のビルドは PostToolUse でファイルパスを蓄積し、Stop hook で一括実行する。

- `auto-build.sh` (PostToolUse): `.swift` / `project.yml` 変更時にパスを `/tmp/claude-build-accumulator.txt` に追記するだけ
- `stop-build.sh` (Stop): 蓄積ファイルを消費 → xcodebuild → シミュレータ install+launch
- 連続 Edit 中はビルドしない。応答完了時に一括実行

**Why:** PostToolUse で毎回ビルドすると連続 Edit でビルドが衝突する。accumulator + Stop が業界標準 (ECC 方式)。

### `-derivedDataPath ./build` を必ず指定

```bash
xcodebuild -project CreateLog.xcodeproj -scheme CreateLog \
  -destination 'platform=iOS Simulator,id=8BBEFBCE-2E2E-469B-98E5-6C16EC90BB22' \
  -derivedDataPath ./build build
```

**Why:** 指定しないと `~/Library/Developer/Xcode/DerivedData/` が使われ、hook のインストールパスと不一致になる。

### `static let` 変更時は clean build 必須

Swift の `static let` / `private static let` / コンパイル時定数を編集したビルドコマンドには必ず `clean` を付けろ:

```bash
xcodebuild -project CreateLog.xcodeproj -scheme CreateLog \
  -derivedDataPath ./build clean build
```

**Why:** インクリメンタルビルドは `static let` の再コンパイルを skip することがあり、値を変更してもバイナリに反映されない。通常の編集では incremental build で問題ない。static/const 変更時だけ clean を強制する。

## Hook 開発ルール

### `set -e` と command substitution を組み合わせるな

```bash
# 禁止: set -e + $() → コマンド失敗時に即死、エラーハンドリングに到達しない
set -euo pipefail
OUTPUT=$(some_command)  # some_command が失敗 → スクリプト即終了
if [ $? -ne 0 ]; then  # ← 到達しない
  echo "error"
fi

# 正解: set -e を外すか、|| true を付ける
set -uo pipefail  # -e なし
OUTPUT=$(some_command) || true
if echo "$OUTPUT" | grep -q 'SUCCEEDED'; then
  # success
else
  # failure
fi
```

**Why:** 2026-04-12 に stop-build.sh / task-completed.sh で発見。ビルド失敗時にエラーメッセージが表示されず、TaskCompleted hook が exit 2 (完了拒否) でなく exit 1 で終了していた。
