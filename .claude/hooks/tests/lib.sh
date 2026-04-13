#!/bin/bash
# Test library for .claude/hooks/ test suite.
# Provides assertion helpers and test runner utilities.

# カラー出力 (端末対応時のみ)
if [ -t 1 ]; then
  C_RED=$(printf '\033[31m')
  C_GREEN=$(printf '\033[32m')
  C_YELLOW=$(printf '\033[33m')
  C_RESET=$(printf '\033[0m')
else
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_RESET=""
fi

# グローバル状態
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_SUITE=""
FAILURES=()

# プロジェクトパス (hooks を実行する時のデフォルト CLAUDE_PROJECT_DIR)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
HOOKS_DIR="$PROJECT_DIR/.claude/hooks"

# プロジェクト別 accumulator (プロジェクトパスのハッシュ)
PROJECT_HASH=$(echo "$PROJECT_DIR" | shasum -a 256 | cut -c1-12)
ACCUM_FILE="/tmp/claude-build-accumulator-${PROJECT_HASH}.txt"
LOCK_FILE="/tmp/claude-build-${PROJECT_HASH}.lock"

# ----- アサーション -----

# assert_exit_code <expected_code> <actual_code> <test_name>
assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local name="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$expected" = "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ${C_GREEN}PASS${C_RESET}: $name (exit $actual)"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILURES+=("$CURRENT_SUITE: $name (expected exit $expected, got $actual)")
    echo "  ${C_RED}FAIL${C_RESET}: $name (expected exit $expected, got $actual)"
  fi
}

# assert_contains <haystack> <needle> <test_name>
assert_contains() {
  local haystack="$1"
  local needle="$2"
  local name="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if echo "$haystack" | grep -qF "$needle"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ${C_GREEN}PASS${C_RESET}: $name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILURES+=("$CURRENT_SUITE: $name (output does not contain '$needle')")
    echo "  ${C_RED}FAIL${C_RESET}: $name"
    echo "    Expected to contain: $needle"
    echo "    Actual: $haystack"
  fi
}

# assert_not_contains <haystack> <needle> <test_name>
assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local name="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if echo "$haystack" | grep -qF "$needle"; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILURES+=("$CURRENT_SUITE: $name (output unexpectedly contains '$needle')")
    echo "  ${C_RED}FAIL${C_RESET}: $name"
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ${C_GREEN}PASS${C_RESET}: $name"
  fi
}

# assert_file_exists <path> <test_name>
assert_file_exists() {
  local path="$1"
  local name="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -f "$path" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ${C_GREEN}PASS${C_RESET}: $name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILURES+=("$CURRENT_SUITE: $name (file not found: $path)")
    echo "  ${C_RED}FAIL${C_RESET}: $name"
  fi
}

# assert_file_not_exists <path> <test_name>
assert_file_not_exists() {
  local path="$1"
  local name="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ ! -f "$path" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ${C_GREEN}PASS${C_RESET}: $name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILURES+=("$CURRENT_SUITE: $name (unexpected file: $path)")
    echo "  ${C_RED}FAIL${C_RESET}: $name"
  fi
}

# ----- ユーティリティ -----

# run_hook <hook_name> <input> → stdout
# Runs hook with given JSON input. Returns stdout, sets HOOK_EXIT_CODE.
run_hook() {
  local hook="$1"
  local input="$2"
  local out
  out=$(printf '%s' "$input" | CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$HOOKS_DIR/$hook" 2>&1)
  HOOK_EXIT_CODE=$?
  echo "$out"
}

# run_hook_unset_dir <hook_name> <input> → stdout (CLAUDE_PROJECT_DIR を明示的に unset)
run_hook_unset_dir() {
  local hook="$1"
  local input="$2"
  local out
  out=$(printf '%s' "$input" | env -u CLAUDE_PROJECT_DIR bash "$HOOKS_DIR/$hook" 2>&1)
  HOOK_EXIT_CODE=$?
  echo "$out"
}

# ----- テストスイート制御 -----

suite() {
  CURRENT_SUITE="$1"
  echo ""
  echo "${C_YELLOW}=== $1 ===${C_RESET}"
}

cleanup_tmp() {
  rm -f "$ACCUM_FILE" "$LOCK_FILE"
  rm -f /tmp/claude-test-*.json /tmp/claude-test-*.txt
}

summary() {
  echo ""
  echo "=========================================="
  if [ "$TESTS_FAILED" -eq 0 ]; then
    echo "${C_GREEN}All tests passed: $TESTS_PASSED/$TESTS_RUN${C_RESET}"
    return 0
  else
    echo "${C_RED}FAILED: $TESTS_FAILED/$TESTS_RUN (passed: $TESTS_PASSED)${C_RESET}"
    echo ""
    echo "Failures:"
    for f in "${FAILURES[@]}"; do
      echo "  - $f"
    done
    return 1
  fi
}
