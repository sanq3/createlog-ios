#!/bin/bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATE_FILE="$PROJECT_DIR/.claude/session-state.md"

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)

if [ -n "$FILE_PATH" ] && [ -f "$STATE_FILE" ]; then
    REL_PATH="${FILE_PATH#$PROJECT_DIR/}"
    TIMESTAMP=$(date '+%H:%M')

    if ! grep -qF "$REL_PATH" "$STATE_FILE" 2>/dev/null; then
        # 変更ファイル数を20件に制限
        FILE_COUNT=$(grep -c '^\- `' "$STATE_FILE" 2>/dev/null || echo "0")
        if [ "$FILE_COUNT" -lt 20 ]; then
            if grep -q "## 変更したファイル" "$STATE_FILE" 2>/dev/null; then
                sed -i '' "/## 変更したファイル/a\\
- \`$REL_PATH\` ($TIMESTAMP)" "$STATE_FILE" 2>/dev/null || true
            fi
        fi
    fi
fi

exit 0
