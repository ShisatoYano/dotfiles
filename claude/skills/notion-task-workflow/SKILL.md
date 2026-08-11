---
name: notion-task-workflow
description: Use when the user wants to run their Notion-based daily task workflow: deciding today's tasks from their assigned Notion task database, recording progress on a task's Notion page during work, marking a task complete, or wrapping up the day's work into a local summary. Trigger on phrases like "今日のタスク決めて", "進捗記録して", "タスク完了", "今日のまとめ作って". Also apply the progress-recording step proactively when a long work session on a Notion-tracked task is approaching context compaction, per the user's global CLAUDE.md instruction to hand off progress at a good breakpoint — write that handoff to the task's Notion page, not just the conversation.
---

# Notion Task Workflow

Notion上の担当タスクDBを軸にした1日の業務フロー(朝のタスク選定 → 作業中の進捗記録 → タスク完了 → 終業時のまとめ)を支援する。

## 前提

- Notionへのアクセスは公式リモートMCP(`mcp__notion__*`ツール)経由で行う。専用スクリプトは使わない
- タスクDBのプロパティ名(担当者・優先度・期限・見積工数・ステータス)はこのSkillにハードコードしない。初回利用時、またはプロパティの扱いに迷った場合は、対象のタスクデータベースをNotion MCPで検索してプロパティ一覧(実際のプロパティ名・型、ステータスの完了に相当する値)を確認してから使う。DB側の変更にプロパティ名が追従できなくなるのを避けるため
- 日次まとめの保存にはこのdotfilesの`nb`(ノート管理CLI)を使う。業務用notebookは`eightknot`。`nba`/`nbsum`と同様、`nb add --filename "<path>.md" --content "<text>"`でその場作成する(`shell/aliases.sh`参照)

## サブワークフロー1: 今日のタスク決定

トリガー例: 「今日のタスク決めて」

1. `nb search --path` などで`eightknot` notebook内の直近の`daily/*.md`を確認し、前日までの持ち越し・未完了タスクがあれば把握する
2. Notion MCPでタスクDBを検索し、自分にアサインされた未完了タスクを取得する
3. その日の稼働予算(人日)をユーザーに確認する。指定がなければ1.0人日をデフォルトとする(会議等で稼働時間は日によって変わるため、固定値にしない)
4. 期限昇順 → 優先度の順にソートし、見積工数(人日)の累計が稼働予算に収まるところまで貪欲にリストアップする
5. 提案リスト(タスク名・優先度・期限・見積工数・Notionページへのリンク)をユーザーに提示し、確認・調整を受ける。このリストがそのままその日の作業対象になる

## サブワークフロー2: 進捗記録

トリガー例: 「進捗記録して」。加えて、Notionタスクに紐づく作業セッションが長くなりコンテキスト圧縮が近づいた場合、ユーザーのグローバルCLAUDE.mdの指示(区切りの良いところで進捗をまとめ次セッションに引き継ぐ)に従って進捗をまとめる際は、この手順を使ってNotionページにも同じ内容を残す(会話内サマリだけで終わらせない)。

1. 対象タスクを特定する。会話内で明らかならそれを使う。不明なら、タスク名やNotionページURLをユーザーに確認するか、Notion検索で解決する
2. 作業内容・現状・次にやること(ブロッカーがあればそれも)を簡潔なMarkdownでまとめる
3. 対象タスクのNotionページに追記する(既存の内容を上書きしない)
