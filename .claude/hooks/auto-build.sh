#!/bin/bash
# PostToolUse hook: *.swift 変更時に自動ビルド → シミュレータ起動
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || true)

# .swift ファイル以外は無視
[[ "$FILE_PATH" == *.swift ]] || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# project.yml が変わっていたら xcodegen を先に実行
if git diff --name-only HEAD 2>/dev/null | grep -q 'project.yml'; then
  xcodegen generate 2>/dev/null || true
fi

# インクリメンタルビルド
xcodebuild -project CreateLog.xcodeproj -scheme CreateLog \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -3

# シミュレータにインストール&起動
xcrun simctl terminate booted com.sanq3.createlog 2>/dev/null || true
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/CreateLog.app 2>/dev/null || true
xcrun simctl launch booted com.sanq3.createlog 2>/dev/null || true
