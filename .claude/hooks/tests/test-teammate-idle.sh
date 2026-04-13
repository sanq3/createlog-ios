#!/bin/bash
# Tests for teammate-idle.sh (TeammateIdle hook, stall prevention)
set -uo pipefail

source "$(dirname "$0")/lib.sh"

suite "teammate-idle.sh: stall 防止"

FAKE_TASKS_DIR="/tmp/claude-test-tasks"
TEST_HOOK="/tmp/claude-test-teammate-idle.sh"

# テスト用 hook: TASKS_DIR を一時ディレクトリに差し替え
sed "s|TASKS_DIR=\"\$HOME/.claude/tasks/createlog-dev\"|TASKS_DIR=\"$FAKE_TASKS_DIR\"|" \
  "$HOOKS_DIR/teammate-idle.sh" > "$TEST_HOOK"
chmod +x "$TEST_HOOK"

# Test 1: Tasks dir doesn't exist → exit 0
rm -rf "$FAKE_TASKS_DIR"
echo '{}' | bash "$TEST_HOOK" >/dev/null
assert_exit_code 0 $? "no tasks dir → exit 0"

# Test 2: Empty tasks dir → exit 0
mkdir -p "$FAKE_TASKS_DIR"
echo '{}' | bash "$TEST_HOOK" >/dev/null
assert_exit_code 0 $? "empty tasks dir → exit 0"

# Test 3: Pending task with owner → exit 0 (not available)
cat > "$FAKE_TASKS_DIR/1.json" <<EOF
{"id":"1","status":"pending","owner":"someone","blockedBy":[]}
EOF
echo '{}' | bash "$TEST_HOOK" >/dev/null
assert_exit_code 0 $? "assigned pending task → exit 0"

# Test 4: Pending task blocked → exit 0
cat > "$FAKE_TASKS_DIR/1.json" <<EOF
{"id":"1","status":"pending","owner":"","blockedBy":["99"]}
EOF
echo '{}' | bash "$TEST_HOOK" >/dev/null
assert_exit_code 0 $? "blocked pending task → exit 0"

# Test 5: Unassigned pending task → exit 2
cat > "$FAKE_TASKS_DIR/1.json" <<EOF
{"id":"1","status":"pending","owner":"","blockedBy":[]}
EOF
out=$(echo '{}' | bash "$TEST_HOOK" 2>&1)
EC=$?
assert_exit_code 2 "$EC" "unassigned pending task → exit 2"
assert_contains "$out" "pending タスクが" "feedback message output"

# Test 6: Malformed JSON → exit 0 (graceful degradation)
cat > "$FAKE_TASKS_DIR/bad.json" <<EOF
not valid json
EOF
# No unassigned pending → should exit 0 (malformed ignored)
rm -f "$FAKE_TASKS_DIR/1.json"
echo '{}' | bash "$TEST_HOOK" >/dev/null
assert_exit_code 0 $? "malformed JSON alone → exit 0 (graceful)"

# Test 7: Malformed JSON + valid unassigned → still detects valid
cat > "$FAKE_TASKS_DIR/2.json" <<EOF
{"id":"2","status":"pending","owner":"","blockedBy":[]}
EOF
out=$(echo '{}' | bash "$TEST_HOOK" 2>&1)
EC=$?
assert_exit_code 2 "$EC" "malformed + valid pending → exit 2"

# Cleanup
rm -rf "$FAKE_TASKS_DIR" "$TEST_HOOK"
