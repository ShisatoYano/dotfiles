---
name: notion-task-workflow
description: Use when the user wants to record progress on a Notion task page during work, or mark a Notion task complete. Trigger on phrases like "進捗記録して", "タスク完了". End-of-day wrap-up (サブワークフロー3) is normally triggered via the `daily-summary` agent (model: haiku) instead of this Skill directly — see that agent's description — but this Skill still contains and can directly run サブワークフロー3 when explicitly invoked. Also apply the progress-recording step proactively when a long work session on a Notion-tracked task is approaching context compaction, per the user's global CLAUDE.md instruction to hand off progress at a good breakpoint — write that handoff to the task's Notion page, not just the conversation. Deciding what to work on today is handled by the separate `daily-task-workflow` Skill (via its `notion-task-planning` sub-step, which reads this Skill's Notion property conventions read-only); this Skill is what actually writes to those tasks' Notion pages once work is underway.
---

# Notion Task Workflow

Notion上の担当タスクページを軸にした業務フロー(作業中の進捗記録 → タスク完了 → 終業時のまとめ)を支援する。その日どのタスクに取り組むかの選定は`daily-task-workflow` Skill(の`notion-task-planning`サブステップ)が行う。

## 前提

- Notionへのアクセスは公式リモートMCP(`mcp__notion__*`ツール)経由で行う。専用スクリプトは使わない。MCPサーバーが未登録の場合は`claude mcp add --transport http notion https://mcp.notion.com/mcp --scope user`の実行を、登録済みだが未認証の場合は`/mcp`での認証をユーザーに促す(まだ利用が固まっていない連携のため、`scripts/setup.sh`には恒久的な登録手順を入れていない)
- タスクDB(ユーザーが日常的に更新するプロパティは`担当者`・`優先度`・`期限`・`ステータス`。加えて`種類`が`Issue (Fix)`の場合は不具合系タスクを表す)のURL/データソースIDはこのSkillにハードコードしない。過去に確認済みならAIメモリを参照し、未確認ならユーザーに確認するかNotion検索で探す。プロパティ名や値がここに書いた内容と食い違う場合は、対象データベースをNotion MCPで検索してスキーマ(実際のプロパティ名・型、ステータスの完了に相当する値)を確認し直す。DB側の変更に追従できなくなるのを避けるため
- 日次まとめの保存にはこのdotfilesの`nb`(ノート管理CLI)を使う。notebookは`daily-task-logs`固定。`nb notebooks`で存在を確認し、無ければ`nb notebooks add daily-task-logs`で作成してから使う。書き込み手順は「共通: daily-task-logsへの書き込み」を参照
- Notionページへの書き込み(進捗記録・ステータス更新)は、承認を得てから実行する(`~/dotfiles/claude/rules/write-approval.md`参照)。コンテキスト圧縮が近づいた際の自動サマリでも、この承認ステップを省略しない
- 進捗は履歴として追記せず、常に最新状態の1セクションに置き換える。古い記述まで読むと次のセッションの作業精度が落ちるため。書き方は`references/progress-record-format.md`に従う(旧内容はNotionのページ履歴から戻せる)

## 共通: daily-task-logsへの書き込み

`daily-task-logs`の当日ファイル(`daily/<YYYY-MM-DD>.md`)への書き込みは、サブワークフロー1(コンテキスト区切り時)とサブワークフロー3(終業時)の両方から使われる共通手順。1日に複数回書き込まれうるが、同じタスクのセクションは積み重ねず最新の1つに差し替える。

1. `nb ls daily-task-logs:daily/<YYYY-MM-DD>.md`の終了コードで、その日のファイルが既に存在するか確認する
2. 書き込む本文をWrite toolでスクラッチパッドの一時ファイルに書く(`nb add --content`/`nb edit --content`には渡さない。AI生成のMarkdownはバッククォートや引用符を含みやすく、シェル経由で渡すとコマンド置換やクォート不整合でハング・内容破損を起こすため)。既存ファイルに同じタスクのセクション(または置き換え対象の途中経過)がある場合は、既存ファイルを読み、そのセクションを差し替えたファイル全体を一時ファイルに書く
3. 存在しない(終了コード非0)場合は`nb add daily-task-logs:daily/<YYYY-MM-DD>.md < <一時ファイルパス>`で新規作成する
4. 既に存在する(終了コード0)場合、2でファイル全体を組み立てたなら`nb edit daily-task-logs:daily/<YYYY-MM-DD>.md --overwrite < <一時ファイルパス>`で置き換え(`--overwrite`をファイル指定より前に置くと失敗する)、新しいセクションを足すだけなら`--overwrite`なしの`nb edit`で追記する(`nb add`は同名ファイルへの2回目の書き込みで上書きせず`-1.md`という別ファイルを作ってしまうため、既存ファイルがある場合は必ず`nb edit`を使う)
5. 反映を確認したら一時ファイルを削除する

## サブワークフロー1: 進捗記録

トリガー例: 「進捗記録して」。加えて、Notionタスクに紐づく作業セッションが長くなりコンテキスト圧縮が近づいた場合(`warn-context-threshold.py` hookによるリマインダーを含む)、ユーザーのグローバルCLAUDE.mdの指示(区切りの良いところで進捗をまとめ次セッションに引き継ぐ)に従って進捗をまとめる際は、この手順を使ってNotionページにも同じ内容を残す(会話内サマリだけで終わらせない)。

1. 対象タスクを特定する。会話内で明らかならそれを使う。不明なら、タスク名やNotionページURLをユーザーに確認するか、Notion検索で解決する
2. 対象ページを取得し、既存の進捗記録(前回の`現状`セクション、または旧形式の日付ごとの追記)と今回の作業内容を統合して、`references/progress-record-format.md`の構成で最新状態の`現状`セクションを作る
3. 作ったセクションと、置き換えで消える範囲(どの見出しを削除するか)をユーザーに提示し、承認を得てから対象タスクのNotionページの進捗部分を置き換える(進捗以外の内容は残す)。置き換え後にページを取得し直して反映を確認する
4. コンテキスト区切りが理由の場合、3の要点を`daily-task-logs`の当日ファイルにも`## 途中経過(<HH:MM>、コンテキスト区切り)`という見出しで書く。同じ日に同じタスクの途中経過がすでにあれば差し替える。詳細はNotionページを参照する形にし、再開に必要な次の一手と環境の注意だけを書く。手順は「共通: daily-task-logsへの書き込み」を参照。新しいセッションが`load-context-handoff.py` hookでこれを拾って引き継ぐため、新しいセッションで作業を続ける前提であることをユーザーに伝える

## サブワークフロー2: タスク完了

トリガー例: 「タスク完了」

1. 完了時の最終まとめ(実施内容・成果物へのリンクなど)を、`references/progress-record-format.md`の`完了まとめ`セクションとして作成する
2. `ステータス`の更新後の値を決める。通常は`Done`。中断・見送りなど成功完了ではない場合は`Stale`/`Cancel`など状況に合う値をユーザーに確認する
3. まとめの内容・置き換えで消える範囲・ステータス更新後の値をユーザーに提示し、承認を得てから進捗部分の`完了まとめ`への置き換えとステータスプロパティの更新を行う

## サブワークフロー3: 終業時のまとめ

通常は`daily-summary` agent(`~/dotfiles/claude/agents/daily-summary.md`、model: haiku)経由で以下の手順が実行される。このSkillを直接呼び出す場合の手順は以下の通り。

トリガー例: 「今日のまとめ作って」。加えて、「今日の業務はこれで終了です」等、終業を示唆する発言があった場合も、明示的な依頼がなくてもこのサブワークフローの対象にする(ただし勝手に作り始めず、先に「今日のまとめを作成しましょうか」とユーザーに確認する)

1. (終業を示唆する発言がトリガーの場合のみ)まとめを作成してよいかユーザーに確認する。明示的に「まとめ作って」と依頼された場合はこの確認は不要
2. その日扱ったタスクを特定する。会話内で明らかならそれも使えるが、この手順は別セッション(タスクごとのセッション)から呼ばれることを前提に、それだけに頼らない。自分のタスク一覧を`notion-task-planning`の「手順」2〜3と同じ方法(`担当者`=`me`のrowsモード取得と担当者の検証。ただし今日完了したタスクも拾うためステータスの条件は付けない)で取得し、`Last edited time`が今日のものに絞り込むことで、進捗記録・タスク完了で実際に触れたタスクを会話の記憶に依存せず特定する
3. 2で特定した各タスクの状態(完了/進行中/ブロック)を集計する
4. まとめ本文を作成し、「共通: daily-task-logsへの書き込み」の手順で`daily-task-logs`に保存する。コンテキスト区切りの途中経過が既に当日ファイルにある場合は、その内容をまとめに統合し、途中経過のセクションは残さずファイル全体を置き換える。翌朝の`daily-task-workflow`(の`notion-task-planning`サブステップ)がこれを読んで持ち越しを把握するため、最新のまとめだけが残るようにする
