---
name: daily-task-workflow
description: Use when the user wants to decide what to work on today ("今日のタスク決めて") — lists their assigned Notion tasks and GitHub issues via `task-planning`, lets them pick, drafts a Slack work-thread post for the picked Notion tasks, then works through the picks one by one with `task-workflow`. PR and review work is not included; it runs in a dedicated session via `pr-watch`.
---

# Daily Task Workflow

Notionの担当タスクとGitHubの自分に割り当てられたIssueを一覧にし、その日やるものをユーザーに選んでもらい(サブワークフロー1)、選ばれたタスクにこのセッション内で直接着手する(サブワークフロー2)。PR対応・レビューは専用セッションで`pr-watch`が独立して扱うため、ここでは扱わない。

## サブワークフロー1: 候補選定(candidate-selection)

呼び出し元のセッションで実行する(手順2の`AskUserQuestion`はサブエージェントでは使えないため、このサブワークフローをサブエージェントに任せない)。

トリガー例: 「今日のタスク決めて」

1. `task-planning` SkillをAgentツール(`subagent_type: Explore`、`model: haiku`)に委譲実行し、現在担当になっている未完了のNotionタスクとGitHubのIssueを優先度・期限順にソートした全件リストを得る(`~/dotfiles/claude/rules/context-delegation.md`参照)
2. 1の全件リストを、`AskUserQuestion`ツール(`multiSelect: true`)でチェックボックス形式で選んでもらう。1問最大4択・1回の呼び出しで最大4問(=16項目)の制約があるため、候補がそれを超える場合は優先度などで区切って複数回に分けて呼び出す
3. 選択されたタスクのうちNotionのものについて、Slack投稿用の下書きを作成する(作業スレは業務用なので、GitHubのIssueは載せない。Notionのタスクが無ければ下書きは作らない)。一旦シンプルに、各タスクページのURLをそのまま貼るだけとする(タイトルやリンク記法は付けない)。フォーマットは以下の通り:
   ```
   作業スレ
   • タスク1のページURL
   • タスク2のページURL
   ```
4. 選択したリストと3のSlack下書きを持って`サブワークフロー2`に進む

## サブワークフロー2: 直接実装(direct-implementation)

`サブワークフロー1`で確定したリストを受け取って実行する。

1. 着手前に、Slack下書きがあれば(Notionのタスクを選んでいなければ飛ばして2へ)、Slack下書きを「📋 Slack投稿用下書き」という見出しとコードブロックのみの単独の返答で提示し、「投稿できたら『進めて』と言ってください」と添えてその返答を終える(同じ返答内で作業を続けると後続の出力に埋もれて見落とされるため)。ユーザーの応答を受けてから次に進む
2. リスト上から順に1件ずつ、このセッション内で直接着手する。`task-workflow`を呼び出す(分業か単独かは同Skillの「前提」の判定に従う)
3. 1件が完了する、またはその日の作業として区切りがついたら、次のタスクに進む
4. 確定リストを全件処理し終えたら、`AskUserQuestion`ツールで「終業まとめを作る」か「追加で他のタスクに着手する」かを選択式で確認する
   - 終業まとめを選んだ場合: `daily-summary` agent(`~/dotfiles/claude/agents/daily-summary.md`)を実行して終了する
   - 追加で着手を選んだ場合: `task-planning` SkillをAgentツール(`subagent_type: Explore`、`model: haiku`)に再度委譲実行し、その時点での未完了タスク全件リストを取得する。`AskUserQuestion`(チェックボックス)で追加するタスクを選んでもらい、手順2〜3の要領で直接着手する。全件処理し終えたら4に戻る
