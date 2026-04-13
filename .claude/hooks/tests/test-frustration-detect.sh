#!/bin/bash
# Tests for frustration-detect.sh (UserPromptSubmit)
set -uo pipefail

source "$(dirname "$0")/lib.sh"

suite "frustration-detect.sh: 不満検出"

# Test 1: Normal prompt → no detection
out=$(echo '{"prompt":"普通の質問です"}' | bash "$HOOKS_DIR/frustration-detect.sh" 2>&1)
EC=$?
assert_exit_code 0 "$EC" "normal prompt → exit 0"
assert_not_contains "$out" "frustration-detected" "normal prompt → no tag"

# Test 2: Frustration keywords → detected
for kw in "また同じミス" "いい加減にしろ" "何回言えば" "止まってる"; do
  out=$(echo "{\"prompt\":\"$kw\"}" | bash "$HOOKS_DIR/frustration-detect.sh" 2>&1)
  assert_contains "$out" "frustration-detected" "'$kw' triggers detection"
done

# Test 3: Malformed JSON → no crash
out=$(echo 'not json' | bash "$HOOKS_DIR/frustration-detect.sh" 2>&1)
assert_exit_code 0 $? "malformed JSON → exit 0"

# Test 4: Empty input → no crash
out=$(echo '' | bash "$HOOKS_DIR/frustration-detect.sh" 2>&1)
assert_exit_code 0 $? "empty input → exit 0"
