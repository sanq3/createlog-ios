#!/bin/bash
set +e

INPUT=$(cat 2>/dev/null)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)

if [ -z "$PROMPT" ]; then
    exit 0
fi

# 短すぎるプロンプトはスキップ
PROMPT_LENGTH=$(echo -n "$PROMPT" | wc -c)
if [ "$PROMPT_LENGTH" -lt 10 ]; then
    exit 0
fi

# /brainstorm や /plan が既に含まれていればスキップ
if echo "$PROMPT" | grep -qE '/(brainstorm|plan)'; then
    exit 0
fi

# 実装系キーワードの検出
KEYWORDS="作って|実装して|追加して|作成して|リファクタ|作り直|新しく|組み込|implement|create|build|refactor|develop"
if echo "$PROMPT" | grep -qiE "$KEYWORDS"; then
    echo "<plan-first-reminder>実装リクエスト検出。brainstormまたはplanスキルの使用を検討せよ。</plan-first-reminder>"
fi

exit 0
