#!/bin/bash
# Install git pre-commit hook that runs .claude/hooks/tests/run-all-checks.sh
# when .claude/hooks/ or .claude/settings*.json changes are staged.
#
# Usage: bash .claude/hooks/tests/install-git-hook.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HOOK_FILE="$PROJECT_DIR/.git/hooks/pre-commit"

if [ ! -d "$PROJECT_DIR/.git" ]; then
  echo "Not a git repository: $PROJECT_DIR"
  exit 1
fi

# 既存の pre-commit hook がある場合は backup
if [ -f "$HOOK_FILE" ]; then
  cp "$HOOK_FILE" "$HOOK_FILE.bak.$(date +%s)"
  echo "Existing pre-commit hook backed up."
fi

cat > "$HOOK_FILE" << 'HOOK_EOF'
#!/bin/bash
# Auto-generated pre-commit hook for .claude/hooks/ validation.
# Runs test suite when relevant files are staged.

PROJECT_DIR="$(git rev-parse --show-toplevel)"
STAGED=$(git diff --cached --name-only)

# .claude/hooks/ or .claude/settings*.json または .claude/agents/ が staged か
if echo "$STAGED" | grep -qE '\.claude/(hooks/|settings.*\.json|agents/)'; then
  echo "Running .claude/hooks/ validation..."
  bash "$PROJECT_DIR/.claude/hooks/tests/run-all-checks.sh"
  RESULT=$?
  if [ "$RESULT" -ne 0 ]; then
    echo ""
    echo "============================"
    echo "Pre-commit check FAILED."
    echo "Fix issues or run with --no-verify to skip (not recommended)."
    echo "============================"
    exit 1
  fi
fi

exit 0
HOOK_EOF

chmod +x "$HOOK_FILE"
echo "Installed pre-commit hook at: $HOOK_FILE"
echo ""
echo "Triggered when these paths are staged:"
echo "  - .claude/hooks/*"
echo "  - .claude/settings*.json"
echo "  - .claude/agents/*"
echo ""
echo "Uninstall: rm $HOOK_FILE"
