#!/bin/bash
# Tests for task-completed.sh (TaskCompleted hook, build gate)
set -uo pipefail

source "$(dirname "$0")/lib.sh"

suite "task-completed.sh: ビルド検証ゲート"

# Test 1: CLAUDE_PROJECT_DIR unset → skip (exit 0)
# Run directly without subshell capturing to preserve exit code
printf '%s' '{}' | env -u CLAUDE_PROJECT_DIR bash "$HOOKS_DIR/task-completed.sh" >/dev/null 2>&1
assert_exit_code 0 "$?" "unset CLAUDE_PROJECT_DIR → exit 0 (skip)"

# Test 2: Non-Swift project → skip
printf '%s' '{}' | CLAUDE_PROJECT_DIR=/tmp bash "$HOOKS_DIR/task-completed.sh" >/dev/null 2>&1
assert_exit_code 0 "$?" "non-Swift project → skip"

# Note: We don't test actual build success/failure here because it requires
# modifying source files (destructive) or running a real xcodebuild (slow).
# Those paths are covered by test-stop-build.sh's build logic (same pattern).
