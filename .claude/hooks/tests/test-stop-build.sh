#!/bin/bash
# Tests for stop-build.sh (Stop hook, consumes accumulator)
set -uo pipefail

source "$(dirname "$0")/lib.sh"

suite "stop-build.sh: ビルド統合"

# Test 1: No accumulator file → exit 0 (skip)
cleanup_tmp
run_hook "stop-build.sh" '{}' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "no accumulator → skip"

# Test 2: CLAUDE_PROJECT_DIR unset → safe skip
cleanup_tmp
echo "/tmp/x.swift" > "$ACCUM_FILE"
out=$(run_hook_unset_dir "stop-build.sh" '{}')
assert_exit_code 0 "$HOOK_EXIT_CODE" "unset CLAUDE_PROJECT_DIR → exit 0"
assert_contains "$out" "CLAUDE_PROJECT_DIR not set" "shows skip message"

# Test 3: Lock file exists (fresh) → skip
cleanup_tmp
echo "/tmp/x.swift" > "$ACCUM_FILE"
touch "$LOCK_FILE"
out=$(run_hook "stop-build.sh" '{}')
assert_exit_code 0 "$HOOK_EXIT_CODE" "fresh lock → skip"
assert_contains "$out" "Build already in progress" "shows lock skip message"
rm -f "$LOCK_FILE"

# Test 4: Non-Swift project → exit 0 (just skip silently)
cleanup_tmp
mkdir -p /tmp/non-swift-proj
echo "/tmp/x.swift" > "/tmp/claude-build-accumulator-$(echo /tmp/non-swift-proj | shasum -a 256 | cut -c1-12).txt"
out=$(printf '%s' '{}' | CLAUDE_PROJECT_DIR=/tmp/non-swift-proj bash "$HOOKS_DIR/stop-build.sh" 2>&1)
EC=$?
assert_exit_code 0 "$EC" "non-Swift project → skip silently"
rm -rf /tmp/non-swift-proj
rm -f "/tmp/claude-build-accumulator-$(echo /tmp/non-swift-proj | shasum -a 256 | cut -c1-12).txt"

# Test 5: Lock file is cleaned up via trap
cleanup_tmp
echo "/tmp/nonexistent.swift" > "$ACCUM_FILE"
# Run in a non-project dir to skip actual build but still execute lock logic
run_hook "stop-build.sh" '{}' >/dev/null
assert_file_not_exists "$LOCK_FILE" "lock file cleaned up after execution"
cleanup_tmp

# Test 6: JSON output escaping (simulate by forcing a message)
# We can't easily simulate a build failure with specific content, so we just verify
# the stop-build.sh output is valid JSON when it emits systemMessage
cleanup_tmp
echo "/tmp/x.swift" > "$ACCUM_FILE"
touch "$LOCK_FILE"
out=$(run_hook "stop-build.sh" '{}')
# Parse the JSON output
if echo "$out" | python3 -c "import json,sys; json.loads(sys.stdin.read())" 2>/dev/null; then
  assert_exit_code 0 0 "systemMessage output is valid JSON"
else
  assert_exit_code 0 1 "systemMessage output is valid JSON"
fi
cleanup_tmp
