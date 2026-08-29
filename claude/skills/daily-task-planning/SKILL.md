---
name: daily-task-planning
description: Use when the user wants to decide what to work on today, combining their assigned Notion tasks with PR/review work from the `pr-workflow` Skill into one prioritized list that fits the day's available work-time budget, draft a Slack work-thread post linking that day's Notion tasks, then work through implementation/bugfix tasks directly in the caller session. Trigger on phrases like "今日のタスク決めて". Candidate selection and Slack draft creation (サブワークフロー1) are normally triggered via the `daily-planning` agent (model: haiku) instead of this Skill directly — see that agent's description — but this Skill still contains and can directly run サブワークフロー1 when explicitly invoked. Direct implementation (サブワークフロー2) always runs at the caller session's own model, after the agent returns the confirmed list.
---

# Daily Task Planning

Notionの担当タスクと、PR対応・レビュー(`pr-task-planning`/`pr-workflow` Skill)を合わせて、その日の作業リストを決め(サブワークフロー1)、確定したリスト中の実装/不具合修正タスクにこのセッション内で直接着手する(サブワークフロー2)。

## 前提

- PR対応は先に時間を確保し、残りをNotionタスクの予算にする

## サブワークフロー1: 候補選定(candidate-selection)

通常は`daily-planning` agent(`~/dotfiles/claude/agents/daily-planning.md`、model: haiku)経由で以下の手順が実行される。このSkillを直接呼び出す場合の手順は以下の通り。

トリガー例: 「今日のタスク決めて」

1. その日の総稼働予算(人日)をユーザーに確認する。指定がなければ1.0人日をデフォルトとする(会議等で稼働時間は日によって変わるため、固定値にしない)
2. `pr-task-planning` SkillをAgentツール(`model: haiku`)に委譲実行し、対応が必要なPR/レビュー項目を取得する(`~/dotfiles/claude/rules/context-delegation.md`参照)。取得した項目それぞれについて、対応にかかりそうな時間(人日換算)をユーザーに確認する
3. 2の合計時間は、`pr-workflow`が扱うレビュー・承認・コメント等の軽微な作業を前提に、基本的に1時間以内(人日換算で0.125人日程度)を目安とする(レビュー指摘に伴う修正作業そのものは別途Notionタスクとして扱うため)。大きく超える場合はその旨をユーザーに確認する
4. 総稼働予算から2の見積合計を差し引き、残りを`notion-task-planning`の予算とする
5. `notion-task-planning` SkillをAgentツール(`model: haiku`)に委譲実行し、4で求めた予算内でのNotionタスク候補を得る(`~/dotfiles/claude/rules/context-delegation.md`参照)
6. 2のPR/レビュー項目と5のNotionタスク候補を合わせた候補リストをユーザーに提示し、着手済みタスクの扱いやIssueタスクの優先度、PR対応の見積など状況に応じた入れ替えを含めて確認・調整を受ける。確定したリストがその日の作業対象になる
7. 確定リスト中のNotionタスクについて、Slack投稿用の下書きを作成する(PR/レビュー項目は含めない)。そのまま貼り付ければ投稿できるよう、標準Markdownの`[表示テキスト](URL)`ではなくSlack独自のmrkdwn記法`<URL|表示テキスト>`を使う。各タスクのタイトルをリンクの表示テキストにし、フォーマットは以下の通り:
   ```
   作業スレ
   • <タスク1のページURL|タスク1のタイトル>
   • <タスク2のページURL|タスク2のタイトル>
   ```
8. 確定したリストと7のSlack下書きを呼び出し元にそのまま報告して終了する(`daily-planning` agent経由の場合は起動元セッションへの報告)。実装/不具合修正系タスクへの着手は`サブワークフロー2: 直接実装`が担当するため、ここでは着手しない

## サブワークフロー2: 直接実装(direct-implementation)

`サブワークフロー1`で確定したリストを受け取って実行する。呼び出し元セッションのモデルでそのまま実行する。

1. 確定リスト中の実装/不具合修正系Notionタスクを上から順に、このセッション内で1件ずつ直接着手する。`種類`が`Issue (Fix)`なら`bug-investigation-workflow`、それ以外なら`implementation-workflow`を呼び出す
2. 1件が完了する、またはその日の作業として区切りがついたら、次のタスクに進む。全件処理し終えたら終了する
