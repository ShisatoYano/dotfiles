---
name: daily-task-workflow
description: Use when the user wants to decide what to work on today, combining their assigned Notion tasks with PR/review work from the `pr-workflow` Skill into one list for the user to pick today's tasks from by checking them off, draft a Slack work-thread post linking that day's selected Notion tasks, then work through the selected PR/review items and implementation/bugfix tasks directly in the caller session, in whichever order the user picks that day. Trigger on phrases like "今日のタスク決めて". Candidate listing, selection, and Slack draft creation (サブワークフロー1) are normally triggered via the `daily-planning` agent (model: haiku) instead of this Skill directly — see that agent's description — but this Skill still contains and can directly run サブワークフロー1 when explicitly invoked. Direct implementation (サブワークフロー2) always runs at the caller session's own model, after the agent returns the confirmed list; it also asks the user each day whether to start with PR/review items or Notion tasks.
---

# Daily Task Workflow

Notionの担当タスクと、PR対応・レビュー(`pr-task-planning`/`pr-workflow` Skill)を合わせて一覧にし、その日やるものをユーザーに選んでもらい(サブワークフロー1)、選ばれたPR/レビュー項目・Notionタスクにこのセッション内で直接着手する(サブワークフロー2)。どちらから先に着手するかはその日の予定次第で前後するため、サブワークフロー2側でその都度選んでもらう。

## サブワークフロー1: 候補選定(candidate-selection)

通常は`daily-planning` agent(`~/dotfiles/claude/agents/daily-planning.md`、model: haiku)経由で以下の手順が実行される。このSkillを直接呼び出す場合の手順は以下の通り。

トリガー例: 「今日のタスク決めて」

1. `pr-task-planning` SkillをAgentツール(`model: haiku`)に委譲実行し、対応が必要なPR/レビュー項目を取得する(`~/dotfiles/claude/rules/context-delegation.md`参照)。PR対応は1時間以内で収まる範囲で行う前提とする
2. `notion-task-planning` SkillをAgentツール(`model: haiku`)に委譲実行し、現在担当になっている未完了Notionタスクを優先度・期限順にソートした全件リストを得る(`~/dotfiles/claude/rules/context-delegation.md`参照)
3. 1のPR/レビュー項目と2のNotionタスク全件リストを、`AskUserQuestion`ツール(`multiSelect: true`)でチェックボックス形式で選んでもらう。1問最大4択・1回の呼び出しで最大4問(=16項目)の制約があるため、候補がそれを超える場合はカテゴリ・優先度などで区切って複数回に分けて呼び出す
4. 選択されたリスト中のNotionタスクについて、Slack投稿用の下書きを作成する(PR/レビュー項目は含めない)。一旦シンプルに、各タスクページのURLをそのまま貼るだけとする(タイトルやリンク記法は付けない)。フォーマットは以下の通り:
   ```
   作業スレ
   • タスク1のページURL
   • タスク2のページURL
   ```
5. 選択したリストと4のSlack下書きを呼び出し元にそのまま報告して終了する(`daily-planning` agent経由の場合は起動元セッションへの報告)。実装/不具合修正系タスクへの着手は`サブワークフロー2: 直接実装`が担当するため、ここでは着手しない

## サブワークフロー2: 直接実装(direct-implementation)

`サブワークフロー1`で確定したリストを受け取って実行する。呼び出し元セッションのモデルでそのまま実行する。

1. 確定リストにPR/レビュー項目とNotionタスクの両方が含まれる場合、`AskUserQuestion`で「PRタスクから着手するか、Notionタスクから着手するか」を選んでもらう(その日の予定次第で前後するため固定順にしない)。片方の種類しかなければ確認を省略する
2. 1で決めた順に、グループ単位で以下を行う
   - PR/レビュー項目: リスト上から順に1件ずつ、`pr-workflow` Skillの該当ステップ(自分のPRなら「レビューコメントへの対応支援」→「マージ可否チェック」、アサインされたレビューなら「レビュー実施そのものの支援」)をこのセッション内で実行する。実際の投稿・マージ等の操作はユーザー自身が行うため、支援・下書き作成が終わった時点でそのPRは完了とする
   - Notionタスク: リスト上から順に1件ずつ、このセッション内で直接着手する。`種類`が`Issue (Fix)`なら`bug-investigation-workflow`、それ以外なら`implementation-workflow`を呼び出す
3. 1件が完了する、またはその日の作業として区切りがついたら、次のタスクに進む
4. 確定リストを全件処理し終えたら、`AskUserQuestion`ツールで「終業まとめを作る」か「追加で他のタスクに着手する」かを選択式で確認する
   - 終業まとめを選んだ場合: `daily-summary` agent(`~/dotfiles/claude/agents/daily-summary.md`)を実行して終了する
   - 追加で着手を選んだ場合: `notion-task-planning` SkillをAgentツール(`model: haiku`)に再度委譲実行し、その時点での未完了Notionタスク全件リストを取得する。`AskUserQuestion`(チェックボックス)で追加するタスクを選んでもらい、手順1〜3の要領で直接着手する。全件処理し終えたら4に戻る
