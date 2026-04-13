#!/bin/bash
# Stop hook: 蓄積された変更ファイルがあればビルド + シミュレータ起動。
# auto-build.sh (PostToolUse accumulator) と対で動作する。
set -uo pipefail
# 注意: set -e は意図的に外している。xcodebuild 失敗時にエラーハンドリングが必要。

# プロジェクト別 accumulator (並行セッション衝突を防止)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJECT_HASH=$(echo "$PROJECT_DIR" | shasum -a 256 | cut -c1-12)
ACCUM_FILE="/tmp/claude-build-accumulator-${PROJECT_HASH}.txt"
LOCK_FILE="/tmp/claude-build-${PROJECT_HASH}.lock"

# 蓄積ファイルがなければスキップ
[ -f "$ACCUM_FILE" ] || exit 0

# 排他制御: 同一プロジェクトで既にビルド中なら skip (race condition 防止)
# lockf は macOS に無いので単純なマーカーファイル方式
if [ -f "$LOCK_FILE" ]; then
  LOCK_AGE=$(($(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0)))
  # 10分以上古いロックはスタックしたものとみなして破棄
  if [ "$LOCK_AGE" -lt 600 ]; then
    echo '{"systemMessage":"Build already in progress, skipping."}'
    exit 0
  fi
  rm -f "$LOCK_FILE"
fi
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# 蓄積ファイルを消費 (次回の Stop で二重ビルドしない)
CHANGED_FILES=$(sort -u "$ACCUM_FILE")
rm -f "$ACCUM_FILE"

[ -z "$CHANGED_FILES" ] && exit 0

# CLAUDE_PROJECT_DIR 未設定時は明示的にエラー (誤プロジェクトビルド防止)
if [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
  echo '{"systemMessage":"stop-build.sh: CLAUDE_PROJECT_DIR not set, skipping build."}'
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR" || {
  echo "{\"systemMessage\":\"stop-build.sh: failed to cd to $CLAUDE_PROJECT_DIR\"}"
  exit 0
}

# Xcode プロジェクトが存在しなければスキップ (iOS プロジェクト以外で誤動作防止)
[ -f "CreateLog.xcodeproj/project.pbxproj" ] || exit 0

# project.yml が変わっていたら xcodegen を先に実行
if echo "$CHANGED_FILES" | grep -q 'project.yml'; then
  xcodegen generate 2>/dev/null || true
fi

# インクリメンタルビルド (エラーハンドリングのため || true + 出力で判定)
BUILD_OUTPUT=$(xcodebuild -project CreateLog.xcodeproj -scheme CreateLog \
  -destination 'platform=iOS Simulator,id=8BBEFBCE-2E2E-469B-98E5-6C16EC90BB22' \
  -derivedDataPath ./build \
  build 2>&1) || true

# BUILD SUCCEEDED が出力に含まれるかで判定 (pipefail 環境では exit code が不安定なため)
if echo "$BUILD_OUTPUT" | grep -q 'BUILD SUCCEEDED'; then
  # シミュレータにインストール&起動 (全て failure tolerant)
  xcrun simctl terminate 8BBEFBCE-2E2E-469B-98E5-6C16EC90BB22 com.sanq3.createlog 2>/dev/null || true
  xcrun simctl install 8BBEFBCE-2E2E-469B-98E5-6C16EC90BB22 ./build/Build/Products/Debug-iphonesimulator/CreateLog.app 2>/dev/null || true
  xcrun simctl launch 8BBEFBCE-2E2E-469B-98E5-6C16EC90BB22 com.sanq3.createlog 2>/dev/null || true
  echo '{"systemMessage":"Build succeeded. App installed and launched on simulator."}'
else
  # JSON 安全: ビルド出力から改行と引用符をエスケープ
  SAFE_OUTPUT=$(echo "$BUILD_OUTPUT" | tail -5 | tr '\n' ' ' | sed 's/"/\\"/g' | head -c 200)
  echo "{\"systemMessage\":\"Build FAILED: ${SAFE_OUTPUT}\"}"
fi

exit 0
