---
name: notion-task-planning
description: Use as a sub-step of `daily-task-workflow` to list the user's currently assigned Notion tasks, sorted by priority/deadline, for the user to pick from. Not typically invoked directly by the user.
---

# Notion Task Planning

`daily-task-workflow`から呼ばれる、担当中のNotionタスクを優先度・期限に応じて並び替え、全件リストアップするだけを行うSkill。タスクページへの進捗記録・完了処理・終業まとめは`notion-task-workflow` Skillが扱う(ここでは行わない)。

## 前提

- Notionへのアクセスは公式リモートMCP(`mcp__notion__*`ツール)経由で行う。専用スクリプトは使わない。MCPサーバーが未登録の場合は`claude mcp add --transport http notion https://mcp.notion.com/mcp --scope user`の実行を、登録済みだが未認証の場合は`/mcp`での認証をユーザーに促す
- タスクDB(担当者・優先度・期限・ステータスのプロパティ。`種類`が`Issue (Fix)`の場合は不具合系タスク)のURL/データソースIDはこのSkillにハードコードしない。過去に確認済みならAIメモリを参照し、未確認ならユーザーに確認するかNotion検索で探す(Notion検索を使うのはDB自体を探すときだけで、タスク一覧の取得には使わない)

## 手順

1. `nb search --path` などで`daily-task-logs` notebook(`notion-task-workflow` Skillが書き出す)内の直近の`daily/*.md`を確認し、前日までの持ち越し・未完了タスクがあれば把握する
2. 自分の未完了タスク(`ステータス`が`Doing`または`Backlog`)の一覧を取得する。取得方法は以下に固定する(担当者で絞れない方法を選ぶと他人のタスクが混ざるため)
   - タスクDBを`fetch`してスキーマ(`担当者`・`ステータス`の実際のプロパティ名とステータスの選択肢名)と`collection://`URLを確認する
   - `query-data-sources`の`rows`モードで、`担当者`に`person_contains` + `{"type": "relative", "value": "me"}`、`ステータス`に`status_is` + `is_option`の配列`["Doing", "Backlog"]`の条件を`and`で付け、`limit: 100`で取得する(除外条件やステータスグループで絞ると、どの値が残るかの解釈がぶれて片方が漏れるため、拾う値を明示する)
   - `notion-search`/`ai-search`はプロパティで絞り込めないため、一覧取得には使わない。ビュー経由(ビューが本当に自分に絞られているか保証できない)やSQLモード(ビューのフィルタが適用されない)も使わない
3. 2の結果を検証する。`notion-get-users`(`user_id: "self"`)で自分のユーザーIDを取得し、`担当者`に自分が含まれない行は除外して、除外した件数を報告する。1で把握した持ち越しタスクも、2の結果に残ったものだけを候補にする(他人に再アサイン済み・完了済みのものを拾わないため)
4. `references/priority-criteria.md`の観点に照らして全タスクを並び替える
5. 4で並び替えた未完了タスクを全件リストアップする(予算による絞り込みはしない。その日どれをやるかはユーザーが`daily-task-workflow`側で選ぶ)
