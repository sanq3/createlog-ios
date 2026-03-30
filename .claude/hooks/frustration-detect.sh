#!/bin/bash
set +e

INPUT=$(cat 2>/dev/null)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)

if [ -z "$PROMPT" ]; then
    exit 0
fi

# 怒り・不満・繰り返し訂正のパターン検出
FRUSTRATION="いい加減|アホ|バカ|何回|さっき言った|また同じ|違うって|だから違う|ちゃんと|全然|何度も|ふざけ|いらいら|まただ|同じミス|聞いてない|読んでない|言ったのに|頼むから|まじで"

if echo "$PROMPT" | grep -qiE "$FRUSTRATION"; then
    echo "<frustration-detected>ユーザーの不満を検出。/self-correct スキルを即座に発動し、ミスの根本原因を特定して再発防止を実行せよ。謝罪から始めるな。</frustration-detected>"
fi

exit 0
