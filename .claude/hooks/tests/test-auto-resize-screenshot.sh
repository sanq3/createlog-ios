#!/bin/bash
# Tests for auto-resize-screenshot.sh (PreToolUse:Read + PostToolUse:Bash)
set -uo pipefail

source "$(dirname "$0")/lib.sh"

suite "auto-resize-screenshot.sh: PNG リサイズ対象判定"

# Test 1: Read with file_path outside safe zone → exit 0, no resize
run_hook "auto-resize-screenshot.sh" '{"tool_name":"Read","tool_input":{"file_path":"/Users/foo/Pictures/x.png"}}' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "Read outside safe zone exits 0"

# Test 2: Read with non-existent /tmp PNG → exit 0 (file check skip)
run_hook "auto-resize-screenshot.sh" '{"tool_name":"Read","tool_input":{"file_path":"/tmp/nonexistent-abc.png"}}' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "Read non-existent /tmp PNG exits 0"

# Test 3: Read with non-PNG file → exit 0 (no resize attempt)
run_hook "auto-resize-screenshot.sh" '{"tool_name":"Read","tool_input":{"file_path":"/tmp/x.txt"}}' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "Read .txt file exits 0"

# Test 4: Bash with screenshot command → exit 0
run_hook "auto-resize-screenshot.sh" '{"tool_name":"Bash","tool_input":{"command":"xcrun simctl io booted screenshot /tmp/foo.png"}}' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "Bash screenshot cmd exits 0"

# Test 5: Bash with unrelated command → exit 0
run_hook "auto-resize-screenshot.sh" '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "Bash non-screenshot cmd exits 0"

# Test 6: Bash with axe screenshot → exit 0
run_hook "auto-resize-screenshot.sh" '{"tool_name":"Bash","tool_input":{"command":"axe screenshot --udid X --output /tmp/bar.png"}}' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "Bash axe screenshot cmd exits 0"

# Test 7: Bash with screencapture → exit 0
run_hook "auto-resize-screenshot.sh" '{"tool_name":"Bash","tool_input":{"command":"screencapture /tmp/cap.png"}}' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "Bash screencapture cmd exits 0"

# Test 8: Malformed JSON → exit 0 graceful
run_hook "auto-resize-screenshot.sh" 'not json at all' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "malformed JSON exits 0 gracefully"

# Test 9: Empty input → exit 0
run_hook "auto-resize-screenshot.sh" '' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "empty input exits 0"

# Test 10: Other tool_name (e.g. Edit) → exit 0 (no-op)
run_hook "auto-resize-screenshot.sh" '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/x.png"}}' >/dev/null
assert_exit_code 0 "$HOOK_EXIT_CODE" "unrelated tool_name exits 0"

summary
