---
name: daily-task-workflow
description: Use when the user wants to decide what to work on today from their assigned Notion tasks, picking today's tasks by checking them off, draft a Slack work-thread post linking the selected tasks, then work through the selected implementation/bugfix tasks directly in the caller session. Trigger on phrases like "今日のタスク決めて". PR/review work is NOT handled here; it runs independently in a dedicated session via `pr-watch`. Candidate listing, selection, and Slack draft creation (サブワークフロー1) are normally triggered via the `daily-planning` agent (model: haiku) instead of this Skill directly — see that agent's description — but this Skill still contains and can directly run サブワークフロー1 when explicitly invoked. Direct implementation (サブワークフロー2) always runs at the caller session's own model, after the agent returns the confirmed list.
---

# Daily Task Workflow

Notionの担当タスクを一覧にし、その日やるものをユーザーに選んでもらい(サブワークフロー1)、選ばれたタスクにこのセッション内で直接着手する(サブワークフロー2)。PR対応・レビューは専用セッションで`pr-watch`が独立して扱うため、ここでは扱わない。

## サブワークフロー1: 候補選定(candidate-selection)

通常は`daily-planning` agent(`~/dotfiles/claude/agents/daily-planning.md`、model: haiku)経由で以下の手順が実行される。このSkillを直接呼び出す場合の手順は以下の通り。

トリガー例: 「今日のタスク決めて」

1. `notion-task-planning` SkillをAgentツール(`model: haiku`)に委譲実行し、現在担当になっている未完了Notionタスクを優先度・期限順にソートした全件リストを得る(`~/dotfiles/claude/rules/context-delegation.md`参照)
2. 1の全件リストを、`AskUserQuestion`ツール(`multiSelect: true`)でチェックボックス形式で選んでもらう。1問最大4択・1回の呼び出しで最大4問(=16項目)の制約があるため、候補がそれを超える場合は優先度などで区切って複数回に分けて呼び出す
3. 選択されたタスクについて、Slack投稿用の下書きを作成する。一旦シンプルに、各タスクページのURLをそのまま貼るだけとする(タイトルやリンク記法は付けない)。フォーマットは以下の通り:
   ```
   作業スレ
   • タスク1のページURL
   • タスク2のページURL
   ```
4. 選択したリストと3のSlack下書きを呼び出し元にそのまま報告して終了する(`daily-planning` agent経由の場合は起動元セッションへの報告)。ユーザーへの下書きの提示は`サブワークフロー2`の手順1で行う。タスクへの着手は`サブワークフロー2: 直接実装`が担当するため、ここでは着手しない

## サブワークフロー2: 直接実装(direct-implementation)

`サブワークフロー1`で確定したリストを受け取って実行する。呼び出し元セッションのモデルでそのまま実行する。

1. 着手前に、Slack下書きを「📋 Slack投稿用下書き」という見出しとコードブロックのみの単独の返答で提示し、「投稿できたら『進めて』と言ってください」と添えてその返答を終える(同じ返答内で作業を続けると後続の出力に埋もれて見落とされるため)。ユーザーの応答を受けてから次に進む
2. リスト上から順に1件ずつ、このセッション内で直接着手する。`種類`が`Issue (Fix)`なら`bug-investigation-workflow`、それ以外なら`implementation-workflow`を呼び出す
3. 1件が完了する、またはその日の作業として区切りがついたら、次のタスクに進む
4. 確定リストを全件処理し終えたら、`AskUserQuestion`ツールで「終業まとめを作る」か「追加で他のタスクに着手する」かを選択式で確認する
   - 終業まとめを選んだ場合: `daily-summary` agent(`~/dotfiles/claude/agents/daily-summary.md`)を実行して終了する
   - 追加で着手を選んだ場合: `notion-task-planning` SkillをAgentツール(`model: haiku`)に再度委譲実行し、その時点での未完了Notionタスク全件リストを取得する。`AskUserQuestion`(チェックボックス)で追加するタスクを選んでもらい、手順2〜3の要領で直接着手する。全件処理し終えたら4に戻る
