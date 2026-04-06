#!/bin/bash
# PreToolUse safety guard for Bash tool.
#
# Primary defense is permissions.deny in .claude/settings.local.json
# (evaluated by Claude Code's built-in permission system). This hook is
# a secondary defense layer that runs independently and blocks at the
# OS level regardless of Claude's judgment.
#
# Blocks:
#   - rm -rf against /, ~, $HOME
#   - git force push, reset --hard, clean -fd*, branch -D, checkout/restore .
#   - supabase db reset
#   - low-level: dd of=/dev/*, mkfs.*
#   - --no-verify (belt & suspenders; ECC block-no-verify also catches this)
#
# Exits:
#   0 — allow
#   2 — block (Claude sees the stderr message)

set -euo pipefail

INPUT=$(cat)

# Extract command. Try python3 first (accurate JSON parse), fall back to sed.
CMD=""
TOOL=""
if command -v python3 >/dev/null 2>&1; then
    read -r TOOL CMD <<<"$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read())
    tool = d.get("tool_name", "")
    cmd = d.get("tool_input", {}).get("command", "") if tool == "Bash" else ""
    # single line, space-separated
    print(tool, cmd.replace("\n", " "))
except Exception:
    pass
' 2>/dev/null || true)"
fi
if [ -z "$CMD" ]; then
    TOOL=$(printf '%s' "$INPUT" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    [ "$TOOL" != "Bash" ] && exit 0
    CMD=$(printf '%s' "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# Not Bash, or empty command → pass through
[ "$TOOL" != "Bash" ] && exit 0
[ -z "$CMD" ] && exit 0

block() {
    echo "[safety-guard] BLOCKED: $1" >&2
    echo "[safety-guard] Command: $CMD" >&2
    echo "[safety-guard] If this is intentional, run it manually in your own terminal." >&2
    exit 2
}

# === rm -rf against root/home ===
if echo "$CMD" | grep -qE '(^|[[:space:];|&])(sudo[[:space:]]+)?rm[[:space:]]+-[a-zA-Z]*[rR][a-zA-Z]*f?[a-zA-Z]*[[:space:]]+(/|~|\$HOME|"\$HOME"|\$\{HOME\})([[:space:]]|$|/\*|;|\|)'; then
    block "rm -rf targeting /, ~, or \$HOME"
fi
if echo "$CMD" | grep -qE '(^|[[:space:];|&])(sudo[[:space:]]+)?rm[[:space:]]+-[a-zA-Z]*f[a-zA-Z]*r?[a-zA-Z]*[[:space:]]+(/|~|\$HOME|"\$HOME"|\$\{HOME\})([[:space:]]|$|/\*|;|\|)'; then
    block "rm -f -r targeting /, ~, or \$HOME"
fi
# Catch rm -rf /* and rm -rf ~/* explicitly (glob wildcards on root/home)
if echo "$CMD" | grep -qE '(^|[[:space:];|&])(sudo[[:space:]]+)?rm[[:space:]]+-[a-zA-Z]+[[:space:]]+(/|~|\$HOME|\$\{HOME\})\*'; then
    block "rm -rf with glob on /, ~, or \$HOME"
fi

# === git destructive operations ===
if echo "$CMD" | grep -qE 'git[[:space:]]+push[[:space:]]+.*(--force[^-]|-f([[:space:]]|$)|--force-with-lease)'; then
    block "git force push"
fi
if echo "$CMD" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard'; then
    block "git reset --hard"
fi
if echo "$CMD" | grep -qE 'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f[a-zA-Z]*d'; then
    block "git clean -fd* (destroys untracked files)"
fi
if echo "$CMD" | grep -qE 'git[[:space:]]+(checkout|restore)[[:space:]]+\.([[:space:]]|$|;)'; then
    block "git checkout/restore . (discards working tree)"
fi
if echo "$CMD" | grep -qE 'git[[:space:]]+branch[[:space:]]+-D[[:space:]]'; then
    block "git branch -D (force delete branch)"
fi

# === supabase destructive ===
if echo "$CMD" | grep -qE 'supabase[[:space:]]+db[[:space:]]+reset'; then
    block "supabase db reset"
fi

# === low-level filesystem ===
if echo "$CMD" | grep -qE '(^|[[:space:];|&])dd[[:space:]].*of=/dev/'; then
    block "dd writing to /dev/"
fi
if echo "$CMD" | grep -qE '(^|[[:space:];|&])mkfs\.'; then
    block "mkfs (filesystem format)"
fi

# === --no-verify (belt & suspenders with ECC block-no-verify) ===
if echo "$CMD" | grep -qE '(^|[[:space:]])(git|npm|yarn|pnpm)[[:space:]].*--no-verify'; then
    block "--no-verify (bypasses pre-commit hooks)"
fi

exit 0
