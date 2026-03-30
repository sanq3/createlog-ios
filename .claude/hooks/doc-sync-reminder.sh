#!/bin/bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

REL_PATH="${FILE_PATH#$PROJECT_DIR/}"

# docs/配下のファイル自体の編集はスキップ（ドキュメント更新中にリマインダーが出ると邪魔）
if echo "$REL_PATH" | grep -qE '^docs/|^CLAUDE\.md$|^\.claude/rules/'; then
    exit 0
fi

# コード変更があった場合にリマインダーを出す
# Models/, Features/, DesignSystem/, App/ の変更が対象
if echo "$REL_PATH" | grep -qE '^CreateLog/(Models|Features|DesignSystem|App)/'; then
    echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[doc-sync] コード変更を検出: '"$REL_PATH"'. 関連ドキュメントの更新が必要か確認せよ。対象: docs/feature-roadmap.md（機能変更時）、CLAUDE.md（構成変更時）、docs/supabase-schema.md（モデル変更時）、.claude/rules/（規約変更時）。変更不要なら無視してよい。"}}'
    exit 0
fi

exit 0
