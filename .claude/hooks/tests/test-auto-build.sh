#!/bin/bash
# Tests for auto-build.sh (PostToolUse accumulator hook)
set -uo pipefail

source "$(dirname "$0")/lib.sh"

suite "auto-build.sh: accumulator パターン"

# Test 1: Edit with .swift file → accumulator gets entry
cleanup_tmp
run_hook "auto-build.sh" '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/a.swift"}}' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "Edit .swift exits 0"
assert_file_exists "$ACCUM_FILE" "Edit .swift creates accumulator"
assert_contains "$(cat "$ACCUM_FILE" 2>/dev/null)" "/tmp/a.swift" "accumulator contains file path"

# Test 2: Write with filePath in tool_response → accumulator
cleanup_tmp
run_hook "auto-build.sh" '{"tool_name":"Write","tool_input":{"file_path":"/tmp/b.swift","content":"x"},"tool_response":{"filePath":"/tmp/b.swift"}}' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "Write .swift exits 0"
assert_contains "$(cat "$ACCUM_FILE" 2>/dev/null)" "/tmp/b.swift" "Write tool_response.filePath used"

# Test 3: MultiEdit → accumulator
cleanup_tmp
run_hook "auto-build.sh" '{"tool_name":"MultiEdit","tool_input":{"file_path":"/tmp/c.swift","edits":[]}}' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "MultiEdit exits 0"
assert_contains "$(cat "$ACCUM_FILE" 2>/dev/null)" "/tmp/c.swift" "MultiEdit accumulates"

# Test 4: Non-swift file → no accumulation
cleanup_tmp
run_hook "auto-build.sh" '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/d.md"}}' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" ".md file exits 0"
assert_file_not_exists "$ACCUM_FILE" ".md file does NOT create accumulator"

# Test 5: project.yml → accumulated
cleanup_tmp
run_hook "auto-build.sh" '{"tool_name":"Edit","tool_input":{"file_path":"/path/to/project.yml"}}' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "project.yml exits 0"
assert_file_exists "$ACCUM_FILE" "project.yml accumulated"

# Test 6: Malformed JSON → no crash, exit 0
cleanup_tmp
run_hook "auto-build.sh" 'not valid json at all' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "malformed JSON exits 0 gracefully"

# Test 7: CLAUDE_PROJECT_DIR not set → falls back to pwd hash
cleanup_tmp
out=$(printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/e.swift"}}' | env -u CLAUDE_PROJECT_DIR bash "$HOOKS_DIR/auto-build.sh" 2>&1)
EC=$?
PWD_HASH=$(echo "$(pwd)" | shasum -a 256 | cut -c1-12)
assert_exit_code 0 "$EC" "no CLAUDE_PROJECT_DIR exits 0"
assert_file_exists "/tmp/claude-build-accumulator-${PWD_HASH}.txt" "falls back to pwd hash"
rm -f "/tmp/claude-build-accumulator-${PWD_HASH}.txt"

# Test 8: Special characters in path (injection safety)
cleanup_tmp
run_hook "auto-build.sh" '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/file;rm -rf /.swift"}}' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "shell metachar in path does not execute"
# Accumulator should contain the literal string, not execute it
assert_contains "$(cat "$ACCUM_FILE" 2>/dev/null)" ";rm -rf" "special chars stored literally"

# Test 9: Multiple projects get separate accumulator files
cleanup_tmp
run_hook "auto-build.sh" '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/p1.swift"}}' >/dev/null
OTHER_HASH=$(echo "/tmp/other-project" | shasum -a 256 | cut -c1-12)
CLAUDE_PROJECT_DIR="/tmp/other-project" bash "$HOOKS_DIR/auto-build.sh" \
  <<< '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/p2.swift"}}' >/dev/null
assert_file_exists "$ACCUM_FILE" "project A accumulator exists"
assert_file_exists "/tmp/claude-build-accumulator-${OTHER_HASH}.txt" "project B accumulator exists"
# They should be different files
if [ "$ACCUM_FILE" != "/tmp/claude-build-accumulator-${OTHER_HASH}.txt" ]; then
  assert_exit_code 0 0 "project A and B use different accumulator files"
else
  assert_exit_code 0 1 "project A and B use different accumulator files"
fi
rm -f "/tmp/claude-build-accumulator-${OTHER_HASH}.txt"
cleanup_tmp

# Test 10: Same project, multiple edits accumulate (not overwrite)
cleanup_tmp
run_hook "auto-build.sh" '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/f1.swift"}}' >/dev/null
run_hook "auto-build.sh" '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/f2.swift"}}' >/dev/null
LINES=$(wc -l < "$ACCUM_FILE" | tr -d ' ')
if [ "$LINES" = "2" ]; then
  assert_exit_code 0 0 "multiple edits accumulate (2 lines)"
else
  assert_exit_code 0 1 "expected 2 lines, got $LINES"
fi

cleanup_tmp
