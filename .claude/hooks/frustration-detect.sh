#!/bin/bash
# UserPromptSubmit hook: ユーザーの不満・怒りパターンを検出し self-correct を発動。
set +e

INPUT=$(cat 2>/dev/null)

# UserPromptSubmit の stdin から prompt を抽出
# jq → python3 → sed の順で fallback
PROMPT=""
if command -v jq >/dev/null 2>&1; then
  PROMPT=$(echo "$INPUT" | jq -r '.prompt // .user_message // .content // empty' 2>/dev/null || true)
elif command -v python3 >/dev/null 2>&1; then
  PROMPT=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('prompt', '') or d.get('user_message', '') or d.get('content', ''))
except:
    pass
" 2>/dev/null || true)
fi

if [ -z "$PROMPT" ]; then
    exit 0
fi

# 怒り・不満・繰り返し訂正のパターン検出
FRUSTRATION="いい加減|アホか|バカか|何回言|さっき言った|また同じ|違うって|だから違う|全然違う|何度も|ふざけ|いらいら|同じミス|聞いてない|読んでない|言ったのに|頼むから|止まってる|動いてない|進んでない"

if echo "$PROMPT" | grep -qiE "$FRUSTRATION"; then
    echo "<frustration-detected>ユーザーの不満を検出。/self-correct スキルを即座に発動し、ミスの根本原因を特定して再発防止を実行せよ。謝罪から始めるな。</frustration-detected>"
fi

exit 0
