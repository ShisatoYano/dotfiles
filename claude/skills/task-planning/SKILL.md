---
name: task-planning
description: Use as a sub-step of `daily-task-workflow` to list the user's currently assigned tasks — Notion tasks and GitHub issues assigned to them in repositories mapped to `github` in `~/.claude/task-sources.json` — sorted by priority/deadline, for the user to pick from. Not typically invoked directly by the user.
---

# Task Planning

`daily-task-workflow`から呼ばれる、担当中のタスク(Notionのタスクと、GitHub Issuesで管理しているリポジトリの自分に割り当てられたIssue)を優先度・期限に応じて並び替え、全件リストアップするだけを行うSkill。タスクへの進捗記録・完了処理・終業まとめは`notion-task-workflow` Skillと`task-workflow`が扱う(ここでは行わない)。

## 前提

- Notionへのアクセスは公式リモートMCP(`mcp__notion__*`ツール)経由で行う。専用スクリプトは使わない。MCPサーバーが未登録の場合は`claude mcp add --transport http notion https://mcp.notion.com/mcp --scope user`の実行を、登録済みだが未認証の場合は`/mcp`での認証をユーザーに促す
- タスクDB(担当者・優先度・期限・ステータスのプロパティ。`種類`が`Issue (Fix)`の場合は不具合系タスク)のURL/データソースIDはこのSkillにハードコードせず、手元のファイル`~/.claude/notion-tasks.json`(`{"database": "<DBのURL>", "data_source": "collection://..."}`。dotfilesに入らないので業務のURLを書いてよい)から読む(サブエージェントや別リポジトリのセッションにはauto memoryが渡らないため、メモリには頼らない)。ファイルが無い、または`fetch`で解決できなければ、ユーザーに確認するかNotion検索で探し、内容を示して承認を得てからファイルに書く(Notion検索を使うのはDB自体を探すときだけで、タスク一覧の取得には使わない)
- GitHubの対象リポジトリは`~/.claude/task-sources.json`で出どころが`github`のものだけ(書式は`~/.claude/skills/task-workflow/references/task-sources.md`の「出どころの決め方」)。ファイルが無い、または`github`が1件も無ければGitHubの手順は飛ばす
- `plan`(作業の順番を決めたGitHub Project)があるリポジトリは、計画に沿った最優先の1件と、前日からの持ち越しのIssueだけを候補にする。計画の見直しはユーザーが行うので、Projectは読むだけで書き換えない

## 手順

1. `nb search --path` などで`daily-task-logs` notebook(`notion-task-workflow` Skillが書き出す)内の直近の`daily/*.md`を確認し、前日までの持ち越し・未完了タスクがあれば把握する
2. 自分の未完了タスク(`ステータス`が`Doing`または`Backlog`)の一覧を取得する。取得方法は以下に固定する(担当者で絞れない方法を選ぶと他人のタスクが混ざるため)
   - タスクDBを`fetch`してスキーマ(`担当者`・`ステータス`の実際のプロパティ名とステータスの選択肢名)と`collection://`URLを確認する
   - `query-data-sources`の`rows`モードで、`担当者`に`person_contains` + `{"type": "relative", "value": "me"}`、`ステータス`に`status_is` + `is_option`の配列`["Doing", "Backlog"]`の条件を`and`で付け、`limit: 100`で取得する(除外条件やステータスグループで絞ると、どの値が残るかの解釈がぶれて片方が漏れるため、拾う値を明示する)
   - `notion-search`/`ai-search`はプロパティで絞り込めないため、一覧取得には使わない。ビュー経由(ビューが本当に自分に絞られているか保証できない)やSQLモード(ビューのフィルタが適用されない)も使わない
3. 2の結果を検証する。`notion-get-users`(`user_id: "self"`)で自分のユーザーIDを取得し、`担当者`に自分が含まれない行は除外して、除外した件数を報告する。1で把握した持ち越しタスクも、2の結果に残ったものだけを候補にする(他人に再アサイン済み・完了済みのものを拾わないため)
4. GitHubの対象リポジトリごとに、次を取得する(シェルのループで束ねず、1リポジトリ1コマンドずつ実行する)。1で把握した持ち越しのIssueは、`plan`の無いリポジトリでは下の割り当ての一覧に残ったものだけを候補にする
   - `plan`があるリポジトリ: Projectの項目から、そのリポジトリのIssue(PRは`pr-watch`の担当なので除く)で`Status`が`Done`でなく、`field`の値があり`exclude`に含まれないものを、`field`の選択肢の順(前ほど先)→`In Progress`を`Todo`より先→Projectでの並び順で並べ、先頭の1件を取る。例: `gh project item-list <番号> --owner <owner> --limit 500 --format json --jq '[.items | to_entries[] | .value + {pos: .key} | select(.content.type == "Issue" and (.content.repository | ascii_downcase) == "<owner/repo>" and .status != "Done" and .step != null and .step != "Later")] | sort_by(.step, (if .status == "In Progress" then 0 else 1 end), .pos) | .[0]'`(`.step`は`field`名の小文字、`"Later"`は`exclude`の値に置き換える。値の名前順が選択肢の順と違うなら`gh project field-list`の順に読み替える)。取れた1件は`gh issue view <番号> --json state,assignees`で確かめ、閉じている・他人に割り当てられている場合は次の項目に進む。加えて、1で把握したそのリポジトリの持ち越しのIssueを、`gh issue list --repo <owner/repo> --state open --limit 500 --json number,title,url,assignees`の結果に残っている(未完了で、他人に割り当てられていない)ものに限って候補に足す(前日に手を付けたものを計画の1件の陰に埋もれさせないため)
   - `plan`が無いリポジトリの、自分に割り当てられた未完了のIssue: `gh issue list --repo <owner/repo> --assignee @me --state open --limit 100 --json number,title,url,labels,milestone`(マイルストーンの期日を期限に使うため、`gh search issues`ではなくこれを使う)
   - 着手済みの判定に使う自分のPR: `gh pr list --repo <owner/repo> --author @me --state open --json number,closingIssuesReferences`
5. `references/priority-criteria.md`の観点に照らして、NotionとGitHubを合わせた全タスクを並び替える
6. 5で並び替えた未完了タスクを、出どころ(Notion / GitHubの`<owner/repo>#<番号>`)とURLを付けて全件リストアップする(予算による絞り込みはしない。その日どれをやるかはユーザーが`daily-task-workflow`側で選ぶ)
