#!/bin/bash
set +e

INPUT=$(cat 2>/dev/null)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)

if [ -z "$PROMPT" ]; then
    exit 0
fi

# 怒り・不満・繰り返し訂正のパターン検出
FRUSTRATION="いい加減|アホか|バカか|何回言|さっき言った|また同じ|違うって|だから違う|全然違う|何度も|ふざけ|いらいら|同じミス|聞いてない|読んでない|言ったのに|頼むから"

if echo "$PROMPT" | grep -qiE "$FRUSTRATION"; then
    echo "<frustration-detected>ユーザーの不満を検出。/self-correct スキルを即座に発動し、ミスの根本原因を特定して再発防止を実行せよ。謝罪から始めるな。</frustration-detected>"
fi

exit 0
