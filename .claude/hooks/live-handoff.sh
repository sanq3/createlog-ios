#!/bin/bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATE_FILE="$PROJECT_DIR/.claude/session-state.md"

mkdir -p "$PROJECT_DIR/.claude"

if [ ! -f "$STATE_FILE" ]; then
    cat > "$STATE_FILE" << 'INIT'
# Session State

## 現在のフォーカス

## 決定事項とその理由

## 変更したファイル

## 発見・注意点

## 次にやること
INIT
fi

# Cooldown: skip if session-state.md was modified within last 5 minutes (reduce noise from repeated prompts)
if [ -f "$STATE_FILE" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        STATE_MTIME=$(stat -f %m "$STATE_FILE" 2>/dev/null || echo 0)
    else
        STATE_MTIME=$(stat -c %Y "$STATE_FILE" 2>/dev/null || echo 0)
    fi
    NOW=$(date +%s)
    ELAPSED=$((NOW - STATE_MTIME))
    if [ "$ELAPSED" -lt 300 ]; then
        exit 0
    fi
fi

LINE_COUNT=$(wc -l < "$STATE_FILE" | tr -d ' ')

if [ "$LINE_COUNT" -gt 80 ]; then
    cat << 'DIRECTIVE'
<live-handoff>
REQUIRED: .claude/session-state.md が肥大化している。重要な情報のみ残して60行以下に書き直せ:
- アクティブな決定事項とその理由
- 現在のフォーカスと次のステップ
- 重要なファイルパスと変更内容
冷たい状態から再開するのに必要な情報だけ残せ。
</live-handoff>
DIRECTIVE
else
    cat << 'DIRECTIVE'
<live-handoff>
REQUIRED: 前回の更新以降で重要な変化があれば .claude/session-state.md の該当セクションに追記:
- 下した決定とその理由
- アーキテクチャやアプローチの変更
- 重要な発見や落とし穴
- フォーカスや次のステップの変更
特筆すべきことがなければスキップしてよい。全体の書き直し禁止、追記のみ。
</live-handoff>
DIRECTIVE
fi

exit 0
