#!/bin/bash
# Tests for session-start.sh / live-handoff.sh / pre-compact-save.sh
set -uo pipefail

source "$(dirname "$0")/lib.sh"

suite "session-start.sh: 初回/復帰"

BACKUP_DIR="/tmp/claude-test-state-backup-$$"
mkdir -p "$BACKUP_DIR"

# バックアップ
if [ -f "$PROJECT_DIR/.claude/session-state.md" ]; then
  cp "$PROJECT_DIR/.claude/session-state.md" "$BACKUP_DIR/session-state.md"
fi
if [ -f "$PROJECT_DIR/.claude/session-state.md.bak" ]; then
  cp "$PROJECT_DIR/.claude/session-state.md.bak" "$BACKUP_DIR/session-state.md.bak"
fi

# Test 1: session-state.md not exist → "新規セッション" message
rm -f "$PROJECT_DIR/.claude/session-state.md"
rm -f "$PROJECT_DIR/.claude/session-state.md.bak"
out=$(CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$HOOKS_DIR/session-start.sh" 2>&1)
EC=$?
assert_exit_code 0 "$EC" "no state → exit 0"
assert_contains "$out" "新規セッション" "no state → shows 'new session' message"

# Test 2: session-state.md exists → shown
echo "# Test State" > "$PROJECT_DIR/.claude/session-state.md"
out=$(CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$HOOKS_DIR/session-start.sh" 2>&1)
EC=$?
assert_exit_code 0 "$EC" "state exists → exit 0"
assert_contains "$out" "Test State" "state content shown"

# Test 3: Only .bak exists → restored from backup
rm -f "$PROJECT_DIR/.claude/session-state.md"
echo "# Backup State" > "$PROJECT_DIR/.claude/session-state.md.bak"
out=$(CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$HOOKS_DIR/session-start.sh" 2>&1)
EC=$?
assert_exit_code 0 "$EC" "backup restore → exit 0"
assert_contains "$out" "Backup State" "backup restored"
assert_file_exists "$PROJECT_DIR/.claude/session-state.md" "state file restored from backup"

# Restore original state
rm -f "$PROJECT_DIR/.claude/session-state.md" "$PROJECT_DIR/.claude/session-state.md.bak"
[ -f "$BACKUP_DIR/session-state.md" ] && cp "$BACKUP_DIR/session-state.md" "$PROJECT_DIR/.claude/session-state.md"
[ -f "$BACKUP_DIR/session-state.md.bak" ] && cp "$BACKUP_DIR/session-state.md.bak" "$PROJECT_DIR/.claude/session-state.md.bak"
rm -rf "$BACKUP_DIR"

suite "pre-compact-save.sh: バックアップ"

# Run pre-compact-save.sh
out=$(CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$HOOKS_DIR/pre-compact-save.sh" 2>&1)
assert_exit_code 0 $? "pre-compact-save exits 0"
assert_contains "$out" "pre-compact-handoff" "outputs handoff directive"

if [ -f "$PROJECT_DIR/.claude/session-state.md" ]; then
  assert_file_exists "$PROJECT_DIR/.claude/session-state.md.bak" "backup created"
fi
