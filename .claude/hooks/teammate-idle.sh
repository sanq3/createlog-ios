#!/bin/bash
# TeammateIdle hook: teammate が idle になろうとした時に実行。
# pending タスクがあれば exit 2 で「次のタスクを取れ」と返して作業継続させる。
# pending タスクがなければ exit 0 で idle を許可。
set -euo pipefail

TASKS_DIR="$HOME/.claude/tasks/createlog-dev"

# タスクディレクトリが存在しなければ idle 許可
[ -d "$TASKS_DIR" ] || exit 0

# pending かつ owner なし・ブロックなしのタスクを数える
# jq → python3 の順で fallback (set -e 回避のため || true を明示)
AVAILABLE=0
if command -v jq >/dev/null 2>&1; then
  AVAILABLE=$({ find "$TASKS_DIR" -maxdepth 1 -name '*.json' -type f 2>/dev/null || true; } | while read -r f; do
    jq -r 'select(.status == "pending" and (.owner == null or .owner == "") and ((.blockedBy // []) | map(select(. != null and . != "")) | length == 0)) | "1"' "$f" 2>/dev/null || true
  done | wc -l | tr -d ' ' || echo 0)
elif command -v python3 >/dev/null 2>&1; then
  AVAILABLE=$(python3 -c "
import json, glob, os
tasks_dir = os.path.expanduser('~/.claude/tasks/createlog-dev')
count = 0
for f in glob.glob(os.path.join(tasks_dir, '*.json')):
    try:
        d = json.load(open(f))
        if d.get('status') == 'pending' and not d.get('owner') and not any(d.get('blockedBy', [])):
            count += 1
    except:
        pass
print(count)
" 2>/dev/null || echo "0")
fi

# 数値検証 (不正値は 0 扱い)
case "$AVAILABLE" in
  ''|*[!0-9]*) AVAILABLE=0 ;;
esac

if [ "$AVAILABLE" -gt 0 ]; then
  echo "未割当の pending タスクが ${AVAILABLE} 件ある。TaskList で確認して次のタスクを取れ。"
  exit 2
fi

exit 0
