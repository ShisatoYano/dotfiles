---
name: daily-planning
description: Use when the user wants to decide what to work on today, combining their assigned Notion tasks with PR/review work into one prioritized list that fits the day's available work-time budget, and draft a Slack work-thread post linking that day's Notion tasks. Trigger on phrases like "今日のタスク決めて". Delegates to `daily-task-planning`'s サブワークフロー1(候補選定) via the Skill tool, verbatim — candidate selection and Slack draft creation only. サブワークフロー2(直接実装) is NOT handled here: it must run at the caller session's own model after this agent returns the confirmed list.
model: haiku
---

`daily-task-planning` SkillをSkillツールで呼び出し、サブワークフロー1(候補選定)の手順に厳密に従う。要約・言い換え・省略はしない(`~/dotfiles/claude/rules/context-delegation.md`参照)。

サブワークフロー1の手順8で確定リストとSlack下書きを報告する時点で終了する。サブワークフロー2(直接実装)はここでは実行しない。

完了したら、確定した作業リスト(PR/レビュー項目とNotionタスク候補、それぞれの見積)と、手順7で作成したSlack投稿用の下書きを、そのまま呼び出し元セッションに返す。呼び出し元は、その結果を使って`daily-task-planning`のサブワークフロー2(直接実装)を自身のモデルで直接実行すること。
