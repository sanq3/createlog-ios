#!/bin/bash
# 全 hook の静的解析 + 単体テストを実行するマスタースクリプト。
# 変更した時に必ず走らせること。
# 使い方: bash .claude/hooks/tests/run-all-checks.sh
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TESTS_DIR/../../.." && pwd)"
HOOKS_DIR="$PROJECT_DIR/.claude/hooks"
SETTINGS_FILE="$PROJECT_DIR/.claude/settings.json"
SETTINGS_LOCAL="$PROJECT_DIR/.claude/settings.local.json"
AGENTS_DIR="$PROJECT_DIR/.claude/agents"

# カラー
if [ -t 1 ]; then
  C_RED=$(printf '\033[31m')
  C_GREEN=$(printf '\033[32m')
  C_YELLOW=$(printf '\033[33m')
  C_BOLD=$(printf '\033[1m')
  C_RESET=$(printf '\033[0m')
else
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_BOLD=""; C_RESET=""
fi

# グローバル成否
GLOBAL_OK=0

section() {
  echo ""
  echo "${C_BOLD}${C_YELLOW}━━━ $1 ━━━${C_RESET}"
}

fail() {
  GLOBAL_OK=1
  echo "${C_RED}✗ $1${C_RESET}"
}

pass() {
  echo "${C_GREEN}✓ $1${C_RESET}"
}

# ===== 1. bash 構文チェック =====
section "1. bash syntax check"
for f in "$HOOKS_DIR"/*.sh; do
  if bash -n "$f" 2>/dev/null; then
    pass "$(basename "$f")"
  else
    fail "$(basename "$f"): syntax error"
    bash -n "$f"
  fi
done

# ===== 2. shellcheck (optional) =====
section "2. shellcheck (optional)"
if command -v shellcheck >/dev/null 2>&1; then
  for f in "$HOOKS_DIR"/*.sh; do
    # SC2155 (declare and assign separately): too noisy, ignore
    # SC1091 (can't follow source): we control the sourced files
    if shellcheck -e SC2155,SC1091 "$f" >/dev/null 2>&1; then
      pass "$(basename "$f")"
    else
      echo "${C_YELLOW}△ $(basename "$f"):${C_RESET}"
      shellcheck -e SC2155,SC1091 "$f" 2>&1 | head -10 | sed 's/^/    /'
      # 警告のみはエラーにしない (情報レベル)
    fi
  done
else
  echo "${C_YELLOW}shellcheck not installed. brew install shellcheck でインストール推奨${C_RESET}"
fi

# ===== 3. JSON 構文チェック =====
section "3. JSON validation"
for f in "$SETTINGS_FILE" "$SETTINGS_LOCAL"; do
  if [ ! -f "$f" ]; then
    echo "${C_YELLOW}△ $(basename "$f"): not found (skipped)${C_RESET}"
    continue
  fi
  if python3 -c "import json; json.load(open('$f'))" 2>/dev/null; then
    pass "$(basename "$f")"
  else
    fail "$(basename "$f"): invalid JSON"
    python3 -c "import json; json.load(open('$f'))" 2>&1 | head -3
  fi
done

# ===== 4. Hook event 名の schema 準拠 =====
section "4. Hook event name schema compliance"
INVALID_EVENTS=$(python3 -c "
import json
VALID = {'PreToolUse', 'PostToolUse', 'PostToolUseFailure', 'Notification', 'UserPromptSubmit', 'SessionStart', 'SessionEnd', 'Stop', 'StopFailure', 'SubagentStart', 'SubagentStop', 'PreCompact', 'PostCompact', 'PermissionRequest', 'PermissionDenied', 'Setup', 'TeammateIdle', 'TaskCreated', 'TaskCompleted', 'Elicitation', 'ElicitationResult', 'ConfigChange', 'WorktreeCreate', 'WorktreeRemove', 'InstructionsLoaded', 'CwdChanged', 'FileChanged'}
d = json.load(open('$SETTINGS_FILE'))
invalid = [e for e in d.get('hooks', {}) if e not in VALID]
print(','.join(invalid))
" 2>/dev/null)
if [ -z "$INVALID_EVENTS" ]; then
  pass "all event names valid"
else
  fail "invalid event names: $INVALID_EVENTS"
fi

# ===== 5. Agent YAML frontmatter =====
section "5. Agent YAML frontmatter"
for f in "$AGENTS_DIR"/*.md; do
  if [ ! -f "$f" ]; then continue; fi
  if python3 -c "
import yaml
c = open('$f').read()
if not c.startswith('---'):
    exit(1)
parts = c.split('---', 2)
if len(parts) < 3:
    exit(1)
fm = yaml.safe_load(parts[1])
if not fm.get('name') or not fm.get('tools'):
    exit(1)
" 2>/dev/null; then
    pass "$(basename "$f")"
  else
    fail "$(basename "$f"): invalid frontmatter"
  fi
done

# ===== 6. 削除済み hook への stale reference =====
section "6. Stale references (deleted hooks)"
STALE_REFS=$(grep -rn 'confirm-before-edit' "$PROJECT_DIR/.claude/settings.json" "$PROJECT_DIR/.claude/agents/" "$PROJECT_DIR/CLAUDE.md" "$PROJECT_DIR/.claude/rules/" 2>/dev/null | grep -v '\.bak' | grep -v 'session-state.md' || true)
if [ -z "$STALE_REFS" ]; then
  pass "no stale references to deleted hooks"
else
  fail "stale references found:"
  echo "$STALE_REFS" | sed 's/^/    /'
fi

# ===== 7. hook 実行権限 =====
section "7. hook files are executable"
for f in "$HOOKS_DIR"/*.sh; do
  if [ -x "$f" ]; then
    pass "$(basename "$f")"
  else
    fail "$(basename "$f"): not executable (chmod +x required)"
  fi
done

# ===== 8. 参照されている hook 実体の存在 =====
section "8. Referenced hook files exist"
MISSING=$(python3 -c "
import json, os
d = json.load(open('$SETTINGS_FILE'))
project_dir = '$PROJECT_DIR'
missing = []
for event, entries in d.get('hooks', {}).items():
    for entry in entries:
        for h in entry.get('hooks', []):
            cmd = h.get('command', '')
            if 'CLAUDE_PROJECT_DIR' in cmd:
                # Extract script path after \$CLAUDE_PROJECT_DIR
                import re
                m = re.search(r'\\\$CLAUDE_PROJECT_DIR(/[^\s\"]+)', cmd)
                if m:
                    script = project_dir + m.group(1)
                    if not os.path.exists(script):
                        missing.append(script)
print(','.join(missing))
" 2>/dev/null)
if [ -z "$MISSING" ]; then
  pass "all referenced hook files exist"
else
  fail "missing hook files: $MISSING"
fi

# ===== 9. テストカバレッジ: 全 hook に対応するテストが存在するか =====
section "9. Hook test coverage (meta-check)"
COVERAGE_OK=1
for hook in "$HOOKS_DIR"/*.sh; do
  name=$(basename "$hook" .sh)
  test_file="$TESTS_DIR/test-${name}.sh"
  session_test="$TESTS_DIR/test-session-hooks.sh"
  if [ -f "$test_file" ]; then
    continue
  fi
  if [ -f "$session_test" ] && grep -q "$name" "$session_test"; then
    continue
  fi
  fail "$(basename "$hook"): no test file (add test-${name}.sh or reference in test-session-hooks.sh)"
  COVERAGE_OK=0
done
if [ "$COVERAGE_OK" = "1" ]; then
  pass "every hook has test coverage"
fi

# ===== 10. 単体テスト実行 =====
section "10. Unit tests"
for t in "$TESTS_DIR"/test-*.sh; do
  if [ ! -f "$t" ]; then continue; fi
  echo ""
  echo "Running: $(basename "$t")"
  bash "$t"
  if [ $? -ne 0 ]; then
    fail "$(basename "$t"): test suite had failures"
  fi
done

# ===== 最終サマリ =====
echo ""
echo "=========================================="
if [ "$GLOBAL_OK" -eq 0 ]; then
  echo "${C_GREEN}${C_BOLD}All checks passed.${C_RESET}"
  exit 0
else
  echo "${C_RED}${C_BOLD}Some checks FAILED. See above.${C_RESET}"
  exit 1
fi
