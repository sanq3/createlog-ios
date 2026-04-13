#!/bin/bash
# TaskCompleted hook: タスク完了時にビルド検証を実行。
# ビルド失敗なら exit 2 でタスク完了を拒否。
set -uo pipefail
# 注意: set -e は意図的に外している。xcodebuild 失敗時に exit 2 を返す必要がある。

# CLAUDE_PROJECT_DIR 未設定時は検証スキップ (誤ったプロジェクトでビルドを防止)
if [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR" || exit 0

# Xcode プロジェクトが存在しなければスキップ (iOS プロジェクト以外では検証しない)
[ -f "CreateLog.xcodeproj/project.pbxproj" ] || exit 0

# インクリメンタルビルド検証
BUILD_OUTPUT=$(xcodebuild -project CreateLog.xcodeproj -scheme CreateLog \
  -destination 'platform=iOS Simulator,id=8BBEFBCE-2E2E-469B-98E5-6C16EC90BB22' \
  -derivedDataPath ./build \
  build 2>&1) || true

# BUILD SUCCEEDED の有無で判定
if echo "$BUILD_OUTPUT" | grep -q 'BUILD SUCCEEDED'; then
  exit 0
fi

# ビルド失敗 → exit 2 でタスク完了を拒否
SAFE_OUTPUT=$(echo "$BUILD_OUTPUT" | tail -5 | tr '\n' ' ' | sed 's/"/\\"/g' | head -c 200)
echo "ビルド失敗。修正してからタスクを完了マークしろ。エラー: ${SAFE_OUTPUT}"
exit 2
