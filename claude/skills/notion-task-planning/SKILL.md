---
name: notion-task-planning
description: Use as a sub-step of `daily-task-planning` to list the user's currently assigned Notion tasks, sorted by priority/deadline, for the user to pick from. Not typically invoked directly by the user.
---

# Notion Task Planning

`daily-task-planning`から呼ばれる、担当中のNotionタスクを優先度・期限に応じて並び替え、全件リストアップするだけを行うSkill。タスクページへの進捗記録・完了処理・終業まとめは`notion-task-workflow` Skillが扱う(ここでは行わない)。

## 前提

- Notionへのアクセスは公式リモートMCP(`mcp__notion__*`ツール)経由で行う。専用スクリプトは使わない。MCPサーバーが未登録の場合は`claude mcp add --transport http notion https://mcp.notion.com/mcp --scope user`の実行を、登録済みだが未認証の場合は`/mcp`での認証をユーザーに促す
- タスクDB(担当者・優先度・期限・ステータスのプロパティ。`種類`が`Issue (Fix)`の場合は不具合系タスク)のURL/データソースIDや、`担当者`が自分に絞られたビューのURLはこのSkillにハードコードしない。過去に確認済みならAIメモリを参照し、未確認ならユーザーに確認するかNotion検索で探す

## 手順

1. `nb search --path` などで`daily-task-logs` notebook(`notion-task-workflow` Skillが書き出す)内の直近の`daily/*.md`を確認し、前日までの持ち越し・未完了タスクがあれば把握する
2. 自分の未完了タスクの一覧を取得する。ユーザーが用意した「自分のタスク」ビューがあればそれを`query_data_sources`(view mode)で取得する。無ければ、タスクDBを`担当者`に自分を含む条件で検索する
3. 全タスクを以下の目安で並び替える(機械的な絶対順位ではなく判断材料として扱う):
   - `ステータス`が`Doing`(着手済み)のタスクは基本的に他より優先するが、絶対ではない
   - 次点は以下の2グループを**同格**として扱う(どちらかを機械的に優先しない): (a) `期限`があるタスクを期限昇順・優先度順に並べたもの、(b) `期限`が未設定でも`種類`が`Issue (Fix)`かつ`優先度`が`Highest`のタスク
   - 上記以外(期限なし・Issueでもない)は優先度順で最後に並べる
4. 3で並び替えた未完了タスクを全件リストアップする(予算による絞り込みはしない。その日どれをやるかはユーザーが`daily-task-planning`側で選ぶ)
