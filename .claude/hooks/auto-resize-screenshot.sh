#!/bin/bash
# Auto-resize oversized PNG screenshots before Read, and right after screenshot-producing Bash commands.
# Prevents Claude Code session brick from ">2000px in many-image requests" API error
# (known bug: github.com/anthropics/claude-code/issues/46656, #16173, #34566, etc.)
#
# SAFETY: only resizes files in /tmp/, /var/folders/, and $CLAUDE_PROJECT_DIR/.claude/screenshots/.
# Never touches Asset Catalog, repo-tracked PNGs, or user's Pictures directory.

set -uo pipefail

MAX_DIM=1800
THRESHOLD=2000

raw=$(cat)

tool_name=$(echo "$raw" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
paths=""

if [[ "$tool_name" == "Read" ]]; then
    # PreToolUse:Read — inspect the file_path being read
    paths=$(echo "$raw" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
elif [[ "$tool_name" == "Bash" ]]; then
    # PostToolUse:Bash — only react to screenshot-producing commands
    command=$(echo "$raw" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")
    if echo "$command" | grep -qE '(simctl io .* screenshot|axe screenshot|screencapture)'; then
        paths=$(echo "$command" | grep -oE '(/tmp|/private/tmp|/var/folders)[^ "'\'']+\.[pP][nN][gG]' | sort -u || true)
    fi
fi

for p in $paths; do
    case "$p" in
        /tmp/*|/private/tmp/*|/var/folders/*) ;;
        "$CLAUDE_PROJECT_DIR"/.claude/screenshots/*) ;;
        *) continue ;;
    esac

    [ -f "$p" ] || continue

    h=$(sips -g pixelHeight "$p" 2>/dev/null | awk '/pixelHeight:/ {print $2}' || echo "")
    w=$(sips -g pixelWidth "$p" 2>/dev/null | awk '/pixelWidth:/ {print $2}' || echo "")
    [ -n "$h" ] && [ -n "$w" ] || continue

    max=$((h > w ? h : w))
    if [ "$max" -gt "$THRESHOLD" ]; then
        sips -Z "$MAX_DIM" "$p" >/dev/null 2>&1 || continue
        echo "[auto-resize] $p ${w}x${h} -> max ${MAX_DIM}px" >&2
    fi
done

exit 0
