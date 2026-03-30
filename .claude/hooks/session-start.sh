#!/bin/bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATE_FILE="$PROJECT_DIR/.claude/session-state.md"
BACKUP_FILE="$PROJECT_DIR/.claude/session-state.md.bak"

if [ -f "$STATE_FILE" ]; then
    echo "=== 前回のセッション状態 ==="
    cat "$STATE_FILE"
    echo ""
    echo "上記の状態を引き継いで作業を継続せよ。"
elif [ -f "$BACKUP_FILE" ]; then
    echo "=== バックアップから復元 ==="
    cp "$BACKUP_FILE" "$STATE_FILE"
    cat "$STATE_FILE"
    echo ""
    echo "上記の状態を引き継いで作業を継続せよ。"
else
    echo "前回のセッション状態なし。新規セッション。"
fi

exit 0
