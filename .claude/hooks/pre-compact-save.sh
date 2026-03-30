#!/bin/bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATE_FILE="$PROJECT_DIR/.claude/session-state.md"
BACKUP_FILE="$PROJECT_DIR/.claude/session-state.md.bak"

mkdir -p "$PROJECT_DIR/.claude"

if [ -f "$STATE_FILE" ]; then
    cp "$STATE_FILE" "$BACKUP_FILE"
fi

cat << 'DIRECTIVE'
<pre-compact-handoff>
CRITICAL: コンテキスト圧縮が実行される。今すぐ .claude/session-state.md を完全に書き直せ。
圧縮後はこのファイルだけが記憶になる:
- 何に取り組んでいて、なぜか
- 全ての決定事項とその理由
- 重要な発見、落とし穴、ブロッカー
- 重要なファイル:行番号
- 直前に完了したこと
- 次にやるべきこと
圧縮後、何よりも先に .claude/session-state.md を読め。
</pre-compact-handoff>
DIRECTIVE

exit 0
