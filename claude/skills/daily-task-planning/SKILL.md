---
name: daily-task-planning
description: Use when the user wants to decide what to work on today, combining their assigned Notion tasks with PR/review work from the `pr-workflow` Skill into one prioritized list that fits the day's available work-time budget. Trigger on phrases like "今日のタスク決めて".
---

# Daily Task Planning

Notionの担当タスクと、PR対応・レビュー(`pr-task-planning`/`pr-workflow` Skill)を合わせて、その日の作業リストを決める。

## 前提

- PR対応は先に時間を確保し、残りをNotionタスクの予算にする

## 手順

1. その日の総稼働予算(人日)をユーザーに確認する。指定がなければ1.0人日をデフォルトとする(会議等で稼働時間は日によって変わるため、固定値にしない)
2. `pr-task-planning` Skillを実行し、対応が必要なPR/レビュー項目を取得する。取得した項目それぞれについて、対応にかかりそうな時間(人日換算)をユーザーに確認する
3. 2の合計時間は、`pr-workflow`が扱うレビュー・承認・コメント等の軽微な作業を前提に、基本的に1時間以内(人日換算で0.125人日程度)を目安とする(レビュー指摘に伴う修正作業そのものは別途Notionタスクとして扱うため)。大きく超える場合はその旨をユーザーに確認する
4. 総稼働予算から2の見積合計を差し引き、残りを`notion-task-planning`の予算とする
5. `notion-task-planning` Skillを、4で求めた予算で実行し、Notionタスク候補を得る
6. 2のPR/レビュー項目と5のNotionタスク候補を合わせた候補リストをユーザーに提示し、着手済みタスクの扱いやIssueタスクの優先度、PR対応の見積など状況に応じた入れ替えを含めて確認・調整を受ける。確定したリストがその日の作業対象になる
