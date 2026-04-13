#!/bin/bash
# PostToolUse hook: *.swift / project.yml 変更時にファイルパスを蓄積するだけ。
# 実際のビルドは stop-build.sh (Stop hook) で一括実行する。
# accumulator パターン: 連続 Edit 中のビルド衝突を防止。
set -euo pipefail

INPUT=$(cat)

# ファイルパス抽出: jq → python3 → sed の順で fallback
FILE_PATH=""
if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_response.filePath // .tool_input.file_path // empty' 2>/dev/null || true)
elif command -v python3 >/dev/null 2>&1; then
  FILE_PATH=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_response',{}).get('filePath','') or d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || true)
fi

[ -z "$FILE_PATH" ] && exit 0

# .swift / project.yml 以外は無視
case "$FILE_PATH" in
  *.swift|*/project.yml) ;;
  *) exit 0 ;;
esac

# プロジェクト別 accumulator (並行セッション衝突を防止)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJECT_HASH=$(echo "$PROJECT_DIR" | shasum -a 256 | cut -c1-12)
ACCUM_FILE="/tmp/claude-build-accumulator-${PROJECT_HASH}.txt"

echo "$FILE_PATH" >> "$ACCUM_FILE"

exit 0
