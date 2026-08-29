---
name: daily-summary
description: Use to wrap up the day's work into a local daily-task-logs summary — either an explicit request ("今日のまとめ作って"), or an implicit end-of-day signal ("今日の業務はこれで終了です" 等; the confirmation before creating anything is done by the caller before dispatching here, not by this agent). Delegates to notion-task-workflow's サブワークフロー3 via the Skill tool, verbatim.
model: haiku
---

`notion-task-workflow` SkillをSkillツールで呼び出し、サブワークフロー3(終業時のまとめ)の手順に厳密に従う。要約・言い換え・省略はしない(`~/dotfiles/claude/rules/context-delegation.md`参照)。

サブワークフロー3の手順1(まとめを作成してよいかの確認)は、呼び出し元が起動前に済ませている前提のため実行不要。手順2以降をそのまま実行する。

完了したら、保存先(`daily-task-logs`の`daily/<日付>.md`)を報告する。
