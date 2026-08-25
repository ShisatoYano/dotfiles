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
2. `pr-task-planning` SkillをAgentツール(`model: haiku`)に委譲実行し、対応が必要なPR/レビュー項目を取得する(`~/dotfiles/claude/rules/context-delegation.md`参照)。取得した項目それぞれについて、対応にかかりそうな時間(人日換算)をユーザーに確認する
3. 2の合計時間は、`pr-workflow`が扱うレビュー・承認・コメント等の軽微な作業を前提に、基本的に1時間以内(人日換算で0.125人日程度)を目安とする(レビュー指摘に伴う修正作業そのものは別途Notionタスクとして扱うため)。大きく超える場合はその旨をユーザーに確認する
4. 総稼働予算から2の見積合計を差し引き、残りを`notion-task-planning`の予算とする
5. `notion-task-planning` SkillをAgentツール(`model: haiku`)に委譲実行し、4で求めた予算内でのNotionタスク候補を得る(`~/dotfiles/claude/rules/context-delegation.md`参照)
6. 2のPR/レビュー項目と5のNotionタスク候補を合わせた候補リストをユーザーに提示し、着手済みタスクの扱いやIssueタスクの優先度、PR対応の見積など状況に応じた入れ替えを含めて確認・調整を受ける。確定したリストがその日の作業対象になる
7. 確定リスト中の実装/不具合修正系Notionタスクは、いずれも編集(ブランチ操作)を伴うため、基本的に全てHerdrへ委譲する。対象リポジトリは、このセッション自身の作業ディレクトリ(`$PWD`)をデフォルトとして提示する。このセッションで直接進めたいタスクや、`$PWD`と異なるリポジトリのタスクがあれば、その時点でユーザーに確認する
8. 委譲予定タスクごとに、`herdr worktree list --cwd <repo_root>`で、そのタスク用のworktreeが前日以前から既に存在しないか確認する(ブランチ名・パス、必要なら`herdr workspace get <workspace_id>`のlabelを手がかりに判定する。命名は`task-<タスクID>`とは限らず内容ベースのブランチ名の場合もあるため、機械的な文字列一致ではなく内容で判断する)。既存のworktreeが見つかったタスクは新規作成対象から除外し、該当workspaceを`herdr workspace focus <workspace_id>`でフォーカスした上で、`agent_status`が`idle`なら再開を促すプロンプトを`herdr agent prompt`で送る
9. 8で新規作成対象と判定したタスクごとに、`scripts/herdr-task-launch.sh <repo_root> task-<タスクID> "<タスク名>" "<初期プロンプト>"`を、対象件数分の並列Bashツール呼び出しで起動する。初期プロンプトは「Notionタスク<URL>を確認してください。作業に入る前に、必ずユーザーに『このリポジトリのセットアップ(依存関係のインストール・ビルドなど)は完了しているか』を確認してください。自分で必要性を判断して省略しないこと。完了の報告を受けてから、内容に応じて適切なSkill(不具合修正なら`bug-investigation-workflow`、それ以外は`implementation-workflow`)で作業を進めてください。」という定型文とし、詳細な文脈は委譲先セッションがNotionページを読んで自分で再構築する
10. 9の起動結果(`herdr-task-launch.sh`が返すJSON)と、8で再開した既存タスクの状況を合わせてユーザーに提示する。以降の状況把握はHerdr側のTUIに委ねる
