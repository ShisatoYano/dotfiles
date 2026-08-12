---
name: notion-task-workflow
description: Use when the user wants to run their Notion-based daily task workflow: deciding today's tasks from their assigned Notion task database, recording progress on a task's Notion page during work, marking a task complete, or wrapping up the day's work into a local summary. Trigger on phrases like "今日のタスク決めて", "進捗記録して", "タスク完了", "今日のまとめ作って". Also apply the progress-recording step proactively when a long work session on a Notion-tracked task is approaching context compaction, per the user's global CLAUDE.md instruction to hand off progress at a good breakpoint — write that handoff to the task's Notion page, not just the conversation.
---

# Notion Task Workflow

Notion上の担当タスクDBを軸にした1日の業務フロー(朝のタスク選定 → 作業中の進捗記録 → タスク完了 → 終業時のまとめ)を支援する。

## 前提

- Notionへのアクセスは公式リモートMCP(`mcp__notion__*`ツール)経由で行う。専用スクリプトは使わない
- タスクDB(ユーザーが日常的に更新するプロパティは`担当者`・`優先度`・`見積`・`期限`・`ステータス`。加えて`種類`が`Issue (Fix)`の場合は不具合系タスクを表す)のURL/データソースIDや、`担当者`が自分に絞られたビューのURLはこのSkillにハードコードしない。過去に確認済みならAIメモリを参照し、未確認ならユーザーに確認するかNotion検索で探す。プロパティ名や値がここに書いた内容と食い違う場合は、対象データベースをNotion MCPで検索してスキーマ(実際のプロパティ名・型、ステータスの完了に相当する値)を確認し直す。DB側の変更に追従できなくなるのを避けるため
- `見積`はTシャツサイズ(XS〜3XL)で、人日換算は以下を使う: XS(~4h)=0.5日 / S(~1d)=1日 / M(~3d)=3日 / L(~1w)=5日 / 2L(~2w)=10日 / 3L(~3w)=15日 / XL(~1m)=20日 / 2XL(~1.5m)=30日 / 3XL(~2m)=40日(1週=5営業日、1ヶ月=20営業日換算)。同名の`工数`formulaプロパティはSQLクエリ対象外のため使わない
- 日次まとめの保存にはこのdotfilesの`nb`(ノート管理CLI)を使う。業務用notebookは`eightknot`。`nba`/`nbsum`と同様、`nb add --filename "<path>.md" --content "<text>"`でその場作成する(`shell/aliases.sh`参照)
- **Notionページへの書き込み(進捗追記・ステータス更新)は、書く内容を先にユーザーへ提示し、承認を得てから実行する。** 無断で書き込まない。コンテキスト圧縮が近づいた際の自動サマリでも、Notionへの反映はこの承認ステップを省略しない

## サブワークフロー1: 今日のタスク決定

トリガー例: 「今日のタスク決めて」

Notionタスクに加えて、PR対応・レビュー(`pr-workflow` Skillの領域)もその日の作業に含める。PR対応は先に時間を確保し、残りをNotionタスクの予算にする。

1. `nb search --path` などで`eightknot` notebook内の直近の`daily/*.md`を確認し、前日までの持ち越し・未完了タスクがあれば把握する
2. `pr-workflow` Skillの「自分が出したPRのワークフロー」「自分にアサインされたレビューのワークフロー」それぞれのステップ1(一覧・優先度整理)を実行し、対応が必要なPR/レビュー項目を取得する
3. 取得したPR/レビュー項目それぞれについて、対応にかかりそうな時間(人日換算)をユーザーに確認する
4. その日の総稼働予算(人日)をユーザーに確認する。指定がなければ1.0人日をデフォルトとする(会議等で稼働時間は日によって変わるため、固定値にしない)
5. 総稼働予算から3のPR対応見積の合計を差し引き、残りをNotionタスク選定の予算とする
6. 自分の未完了タスクの一覧を取得する。ユーザーが用意した「自分のタスク」ビューがあればそれを`query_data_sources`(view mode)で取得する。無ければ、タスクDBを`担当者`に自分を含む条件で検索する
7. 各タスクの`見積`を人日換算し、以下の目安で並び替えの一次案を作る(機械的な絶対順位ではなく判断材料として扱う):
   - `ステータス`が`Doing`(着手済み)のタスクは基本的に他より優先するが、絶対ではない
   - `期限`がある場合は昇順、次に`優先度`で並べる
   - `期限`が未設定でも、`種類`が`Issue (Fix)`かつ`優先度`が`Highest`のタスクは優先候補に繰り上げる
8. 7の一次案から、見積(人日換算)の累計が5で求めたNotionタスク予算に収まるところまでを候補としてリストアップする
9. PR/レビュー項目(2, 3)とNotionタスク候補(8)を合わせた候補リストをユーザーに提示し、着手済みタスクの扱いやIssueタスクの優先度、PR対応の見積など状況に応じた入れ替えを含めて確認・調整を受ける。確定したリストがその日の作業対象になる

## サブワークフロー2: 進捗記録

トリガー例: 「進捗記録して」。加えて、Notionタスクに紐づく作業セッションが長くなりコンテキスト圧縮が近づいた場合、ユーザーのグローバルCLAUDE.mdの指示(区切りの良いところで進捗をまとめ次セッションに引き継ぐ)に従って進捗をまとめる際は、この手順を使ってNotionページにも同じ内容を残す(会話内サマリだけで終わらせない)。

1. 対象タスクを特定する。会話内で明らかならそれを使う。不明なら、タスク名やNotionページURLをユーザーに確認するか、Notion検索で解決する
2. 作業内容・現状・次にやること(ブロッカーがあればそれも)を簡潔なMarkdownでまとめる
3. まとめた内容をユーザーに提示し、承認を得てから対象タスクのNotionページに追記する(既存の内容を上書きしない)

## サブワークフロー3: タスク完了

トリガー例: 「タスク完了」

1. 完了時の最終まとめ(実施内容・成果物へのリンクなど)を作成する
2. `ステータス`の更新後の値を決める。通常は`Done`。中断・見送りなど成功完了ではない場合は`Stale`/`Cancel`など状況に合う値をユーザーに確認する
3. まとめの内容とステータス更新後の値をユーザーに提示し、承認を得てからタスクページへの追記とステータスプロパティの更新を行う

## サブワークフロー4: 終業時のまとめ

トリガー例: 「今日のまとめ作って」

1. その日扱った各タスクの状態(完了/進行中/ブロック)と、見積もりに対する実績感を集計する
2. `nb add --filename "daily/<YYYY-MM-DD>.md" --content "<まとめ>"`で`eightknot` notebookに保存する。翌朝のサブワークフロー1がこれを読んで持ち越しを把握する
