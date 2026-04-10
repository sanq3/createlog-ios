#!/bin/bash
# CreateLog チーム開発環境 — 1コマンドで4分割 + 各 Claude が役割付きで起動
#
# 使い方: .claude/scripts/team-start.sh
#
# ┌──────────────┬──────────────┐
# │ テックリード   │ レビュアー     │
# │ (claude)     │ (swift-      │
# │              │  reviewer)   │
# ├──────────────┼──────────────┤
# │ プランナー     │ 実装者        │
# │ (ios-        │ (swift-      │
# │  planner)    │  implementer)│
# └──────────────┴──────────────┘

set -euo pipefail

PROJECT="/Users/個人開発/createlog-ios/createlog-ios"

echo "CreateLog チーム環境を起動中..."

# 新しいワークスペースを作成
cmux new-workspace --name "CL Team" --cwd "$PROJECT"
sleep 1.5

# 右に分割（左右2ペイン）
cmux new-split right
sleep 0.5

# 左側を上下に分割
cmux new-split down --surface surface:1
sleep 0.5

# 右側を上下に分割
cmux new-split down --surface surface:2
sleep 0.5

# 構造確認
echo "ペイン構造:"
cmux tree
sleep 0.5

# 各ペインで Claude を起動
# 左上: テックリード（通常の claude — ユーザーとの対話窓口）
cmux send --surface surface:1 "cd $PROJECT && claude\n"

# 右上: レビュアー
cmux send --surface surface:2 "cd $PROJECT && claude --agent swift-reviewer\n"

# 左下: プランナー
cmux send --surface surface:3 "cd $PROJECT && claude --agent ios-planner\n"

# 右下: 実装者
cmux send --surface surface:4 "cd $PROJECT && claude --agent swift-implementer\n"

echo ""
echo "起動完了。各画面の役割:"
echo "  左上: テックリード（メイン対話窓口）"
echo "  右上: swift-reviewer（レビュー専門）"
echo "  左下: ios-planner（設計・計画専門）"
echo "  右下: swift-implementer（実装専門）"
echo ""
echo "使い方:"
echo "  - 基本はテックリード（左上）に指示する"
echo "  - レビューだけ頼みたい時は右上に直接指示"
echo "  - 計画だけ欲しい時は左下に直接指示"
