---
description: CreateLog 3ロール開発チームを起動 (planner/implementer/reviewer)
---

CreateLog 3ロール開発チームを今すぐ起動する。

手順:

1. TeamCreate で `team_name="createlog-dev"`, `description="CreateLog iOS 3ロール開発チーム"`, `agent_type="tech-lead"` を作成する

2. Agent tool で以下3人を **並列で** 生成する:
   - `name="planner"`, `subagent_type="ios-planner"`, `team_name="createlog-dev"`
   - `name="implementer"`, `subagent_type="swift-implementer"`, `team_name="createlog-dev"`
   - `name="reviewer"`, `subagent_type="swift-reviewer"`, `team_name="createlog-dev"`

   各エージェントへの初期プロンプト（最小限でよい）:
   ```
   チーム createlog-dev に参加しました。
   TaskList でタスクを確認し、割り当てられたタスクがあれば作業してください。
   割り当てがまだなら待機してください。
   役割の範囲は .claude/agents/{your-name}.md に従うこと。
   ```

3. 全員生成できたら、チーム準備完了を1行で報告する。

エラーハンドリング:
- 既にチームが存在する場合は、ユーザーに「既存チームをクリーンアップしますか？」と確認する
- エージェント定義が見つからない場合は、どのファイルが不足しているか報告する

補足:
- 各エージェントの役割・制約は `.claude/agents/{name}.md` に定義済み
- 役割外の行動は絶対禁止（agents ファイルの「絶対禁止」セクション参照）
