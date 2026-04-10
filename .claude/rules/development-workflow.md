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
   - Use **swift-implementer** agent (worktree分離)
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

### `static let` 変更時は clean build 必須

Swift の `static let` / `private static let` / コンパイル時定数を編集したビルドコマンドには必ず `clean` を付けろ:

```bash
xcodebuild -project CreateLog.xcodeproj -scheme CreateLog clean build
```

**Why:** インクリメンタルビルドは `static let` の再コンパイルを skip することがあり、値を変更してもバイナリに反映されない。通常の編集では incremental build で問題ない。static/const 変更時だけ clean を強制する。
