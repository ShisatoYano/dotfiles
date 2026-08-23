---
name: notion-task-workflow
description: Use when the user wants to record progress on a Notion task page during work, mark a Notion task complete, or wrap up the day's work into a local summary. Trigger on phrases like "進捗記録して", "タスク完了", "今日のまとめ作って". Also trigger proactively — asking for confirmation before creating anything — when the user signals they're wrapping up for the day without an explicit request, e.g. "今日の業務はこれで終了です", "今日はここまでにします". Also apply the progress-recording step proactively when a long work session on a Notion-tracked task is approaching context compaction, per the user's global CLAUDE.md instruction to hand off progress at a good breakpoint — write that handoff to the task's Notion page, not just the conversation. Deciding what to work on today is handled by the separate `daily-task-planning` Skill, which reads this Skill's Notion property conventions (read-only) to select today's tasks; this Skill is what actually writes to those tasks' Notion pages once work is underway.
---

# Notion Task Workflow

Notion上の担当タスクページを軸にした業務フロー(作業中の進捗記録 → タスク完了 → 終業時のまとめ)を支援する。その日どのタスクに取り組むかの選定は`daily-task-planning` Skillが行う。

## 前提

- Notionへのアクセスは公式リモートMCP(`mcp__notion__*`ツール)経由で行う。専用スクリプトは使わない。MCPサーバーが未登録の場合は`claude mcp add --transport http notion https://mcp.notion.com/mcp --scope user`の実行を、登録済みだが未認証の場合は`/mcp`での認証をユーザーに促す(まだ利用が固まっていない連携のため、`scripts/setup.sh`には恒久的な登録手順を入れていない)
- タスクDB(ユーザーが日常的に更新するプロパティは`担当者`・`優先度`・`見積`・`期限`・`ステータス`。加えて`種類`が`Issue (Fix)`の場合は不具合系タスクを表す)のURL/データソースIDや、`担当者`が自分に絞られたビューのURLはこのSkillにハードコードしない。過去に確認済みならAIメモリを参照し、未確認ならユーザーに確認するかNotion検索で探す。プロパティ名や値がここに書いた内容と食い違う場合は、対象データベースをNotion MCPで検索してスキーマ(実際のプロパティ名・型、ステータスの完了に相当する値)を確認し直す。DB側の変更に追従できなくなるのを避けるため
- `見積`はTシャツサイズ(XS〜3XL)で、人日換算は以下を使う: XS(~4h)=0.5日 / S(~1d)=1日 / M(~3d)=3日 / L(~1w)=5日 / 2L(~2w)=10日 / 3L(~3w)=15日 / XL(~1m)=20日 / 2XL(~1.5m)=30日 / 3XL(~2m)=40日(1週=5営業日、1ヶ月=20営業日換算)。同名の`工数`formulaプロパティはSQLクエリ対象外のため使わない
- 日次まとめの保存にはこのdotfilesの`nb`(ノート管理CLI)を使う。notebookは`daily-task-logs`固定。`nb notebooks`で存在を確認し、無ければ`nb notebooks add daily-task-logs`で作成してから使う。まとめ本文は`nb add --content`に直接渡さない。AI生成のMarkdownはバッククォートや引用符を含みやすく、シェルのコマンド置換・クォート不整合を誘発してハング/内容破損を起こすため(`nba`/`nbsum`のようなURL/短文向けの`--content`利用とは異なる)。代わりにサブワークフロー3の手順を使う
- Notionページへの書き込み(進捗追記・ステータス更新)は、承認を得てから実行する(`~/dotfiles/claude/rules/write-approval.md`参照)。コンテキスト圧縮が近づいた際の自動サマリでも、この承認ステップを省略しない

## サブワークフロー1: 進捗記録

トリガー例: 「進捗記録して」。加えて、Notionタスクに紐づく作業セッションが長くなりコンテキスト圧縮が近づいた場合、ユーザーのグローバルCLAUDE.mdの指示(区切りの良いところで進捗をまとめ次セッションに引き継ぐ)に従って進捗をまとめる際は、この手順を使ってNotionページにも同じ内容を残す(会話内サマリだけで終わらせない)。

1. 対象タスクを特定する。会話内で明らかならそれを使う。不明なら、タスク名やNotionページURLをユーザーに確認するか、Notion検索で解決する
2. 作業内容・現状・次にやること(ブロッカーがあればそれも)を簡潔なMarkdownでまとめる
3. まとめた内容をユーザーに提示し、承認を得てから対象タスクのNotionページに追記する(既存の内容を上書きしない)

## サブワークフロー2: タスク完了

トリガー例: 「タスク完了」

1. 完了時の最終まとめ(実施内容・成果物へのリンクなど)を作成する
2. `ステータス`の更新後の値を決める。通常は`Done`。中断・見送りなど成功完了ではない場合は`Stale`/`Cancel`など状況に合う値をユーザーに確認する
3. まとめの内容とステータス更新後の値をユーザーに提示し、承認を得てからタスクページへの追記とステータスプロパティの更新を行う

## サブワークフロー3: 終業時のまとめ

トリガー例: 「今日のまとめ作って」。加えて、「今日の業務はこれで終了です」等、終業を示唆する発言があった場合も、明示的な依頼がなくてもこのサブワークフローの対象にする(ただし勝手に作り始めず、先に「今日のまとめを作成しましょうか」とユーザーに確認する)

1. (終業を示唆する発言がトリガーの場合のみ)まとめを作成してよいかユーザーに確認する。明示的に「まとめ作って」と依頼された場合はこの確認は不要
2. その日扱ったタスクを特定する。会話内で明らかならそれも使えるが、この手順は別セッション(タスクごとのセッション)から呼ばれることを前提に、それだけに頼らない。自分のタスク一覧(`daily-task-planning`と同じビュー/検索)を取得し、`Last edited time`が今日のものに絞り込むことで、進捗記録・タスク完了で実際に触れたタスクを会話の記憶に依存せず特定する
3. 2で特定した各タスクの状態(完了/進行中/ブロック)と、見積もりに対する実績感を集計する
4. まとめ本文をWrite toolでスクラッチパッドの一時ファイルに書く(`nb add --content`には渡さない。AI生成のMarkdownはバッククォートや引用符を含みやすく、シェル経由で渡すとコマンド置換やクォート不整合でハング・内容破損を起こすため)
5. `nb add daily-task-logs:daily/<YYYY-MM-DD>.md < <一時ファイルパス>`で標準入力から読み込ませ`daily-task-logs` notebookに保存する。翌朝の`daily-task-planning` Skillがこれを読んで持ち越しを把握する
6. 登録成功を確認したら一時ファイルを削除する
7. `pr-workflow` Skillで並列委譲したペイン(`pr-own-check`/`pr-review-check`)のうち、その日のクローズ通知(SendMessage)を受け取り済みで`workspace_id`を記録できているものがあれば、`herdr workspace close <workspace_id>`で削除する。クローズ通知がまだ来ていないものはそのまま残す
