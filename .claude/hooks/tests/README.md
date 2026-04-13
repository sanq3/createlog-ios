# Hook Test Suite

`.claude/hooks/` 配下の全 hook を静的解析 + 単体テストで自動検証する。

## 実行

```bash
bash .claude/hooks/tests/run-all-checks.sh
```

## 何をチェックするか

| # | チェック項目 | 検出する問題 |
|---|-------------|-------------|
| 1 | bash 構文 | `bash -n` で構文エラー |
| 2 | shellcheck | 静的解析 (brew install shellcheck で有効化) |
| 3 | JSON 構文 | settings.json/settings.local.json の妥当性 |
| 4 | Hook event 名 | 未知のイベント名 (TeammateIdle 等を誤記入) |
| 5 | Agent YAML | frontmatter の妥当性 |
| 6 | Stale references | 削除済み hook への参照残り |
| 7 | 実行権限 | chmod +x 忘れ |
| 8 | 参照ファイル存在 | settings.json が指す hook ファイルが実在するか |
| 9 | 単体テスト | 各 hook の全失敗モードを網羅 |

## 既知の失敗モード (テストで網羅)

### auto-build.sh
- [x] Edit/Write/MultiEdit → accumulator
- [x] 非 swift ファイルはスキップ
- [x] project.yml は accumulator
- [x] 壊れた JSON でクラッシュしない
- [x] CLAUDE_PROJECT_DIR 未設定で pwd fallback
- [x] 特殊文字パスの injection 防御
- [x] 複数プロジェクト間の accumulator 分離

### stop-build.sh
- [x] accumulator なし → skip
- [x] CLAUDE_PROJECT_DIR 未設定 → 安全にスキップ
- [x] fresh lock → race 防止
- [x] 非 Swift プロジェクト → skip
- [x] lock クリーンアップ
- [x] 出力 JSON の妥当性

### task-completed.sh
- [x] CLAUDE_PROJECT_DIR 未設定 → skip
- [x] 非 Swift プロジェクト → skip

### teammate-idle.sh
- [x] タスク dir 不在 → skip
- [x] 空の dir → skip
- [x] owner 付き pending → skip
- [x] blocked pending → skip
- [x] 未割当 pending → exit 2
- [x] 壊れた JSON で graceful degradation

### safety-guard.sh
- [x] 安全コマンド (ls, git diff, xcodebuild, grep, npm) → allow
- [x] rm -rf / ~ /* → block
- [x] git push --force, -f → block
- [x] git reset --hard → block
- [x] git clean -fd → block
- [x] git branch -D → block
- [x] supabase db reset → block
- [x] --no-verify → block
- [x] curl|bash → block
- [x] wget|sh → block
- [x] 非 Bash ツール → pass

### frustration-detect.sh
- [x] 通常プロンプト → no detection
- [x] 不満キーワード → 検出
- [x] 壊れた JSON → graceful
- [x] 空入力 → graceful

### session-start.sh / pre-compact-save.sh
- [x] state.md 不在時 → 新規セッションメッセージ
- [x] state.md あり → 内容表示
- [x] .bak のみ → 復元
- [x] pre-compact でバックアップ作成

## 新しい失敗モードを発見したら

1. 該当する `test-*.sh` にテストケースを追加
2. `bash .claude/hooks/tests/run-all-checks.sh` が FAIL することを確認
3. hook を修正
4. テストが PASS することを確認

**一度発見した失敗モードを再発させない。** テストに追加することで永続化する。

## hook 変更時のワークフロー

```bash
# 1. hook を修正
vi .claude/hooks/auto-build.sh

# 2. 全検証を実行
bash .claude/hooks/tests/run-all-checks.sh

# 3. FAIL があれば修正 → 2 に戻る
# 4. PASS なら commit
git add .claude/hooks/
git commit -m "..."
```

## 今後の拡張候補

- git pre-commit hook で自動実行 (任意、導入には `.git/hooks/pre-commit` を設定)
- CI/CD 統合 (GitHub Actions 等)
- shellcheck の CI 必須化
