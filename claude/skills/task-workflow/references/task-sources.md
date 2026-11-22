# タスクの出どころ

`task-workflow`(と`testing-workflow`の独立タスク)が、タスクの出どころごとに読み替える操作。手順の流れは共通で、ここにある操作だけが変わる。

## 出どころの決め方

上から順に見て、最初に決まったものを使う。

1. 渡された入力: NotionのURLなら`notion`、GitHubのIssueの番号やURLなら`github`
2. 対象リポジトリの`CLAUDE.md`に、タスク管理の場所が書かれていればそれ
3. `~/.claude/task-sources.json`(`{"<owner>/<repo>を小文字にしたもの>": "notion" | "github" | "none"}`。作業の順番をGitHub Projectで決めているリポジトリは`{"source": "github", "plan": {"project": "<owner>/<Projectの番号>", "field": "<順番のフィールド名>", "exclude": ["<候補にしない値>"]}}`と書き、`source`を出どころとして読む)。dotfilesに入らない手元のファイルなので、非公開リポジトリの名前を書いてよい。朝のタスク選び(`task-planning`)も、`github`のリポジトリをこの対応表から読む
4. どれでも決まらなければ、`AskUserQuestion`で「Notion / GitHub Issues / 管理なし」を選んでもらい、3に書くかを確認して、承認されたら書く

`none`(管理なし)は口頭の依頼と同じに扱い、下表の記録・完了・起票は行わない(範囲外の課題は報告だけする)。不具合の登録日時が無いので、現象に最初に気付いた時期をユーザーに聞く。

## 出どころごとの操作

| 操作 | `notion` | `github` |
|---|---|---|
| タスク内容の取得 | タスクページ(`タスクのゴール`、`何のため？`など) | `gh issue view <番号> --repo <owner/repo> --comments` |
| 種類の手がかり | `種類`プロパティ(`Issue (Fix)`は不具合、`機能追加 (Add)`/`改善 (Change)`は実装か、内容によってドキュメントなど) | ラベル(`bug`は不具合、`enhancement`等は実装か、内容によってドキュメントなど)。無ければタイトルと本文から判断 |
| 登録日時(不具合の変更履歴の起点) | `Created time` | Issueの`createdAt` |
| 前回までの進捗 | `現状`セクション(`notion-task-workflow`のサブワークフロー1が書いたもの)と、`daily-task-logs`の直近の`daily/*.md`の当該タスクの最新のセクション。旧形式のページは最新の記述を優先し、古い記述は最新の記述だけでは判断できないときに限って読む(後で訂正されていることがあるため) | Issueの最新のコメントと、Issueにつながっているブランチ・PR |
| 進捗の記録 | `notion-task-workflow`のサブワークフロー1(進捗記録) | Issueへのコメント(`gh issue comment`)。外部への書き込みなので、本文を示して承認を得てから |
| 完了 | `notion-task-workflow`のサブワークフロー2(タスク完了) | PRで出すならPR本文の`Closes #<番号>`で、マージ時に自動で閉じる(手で閉じない)。PRを作らないなら、結果を伝えるコメント本文を示し、承認後に`gh issue comment`と`gh issue close` |
| PR本文に入れるリンク | タスクページのURL | `Closes #<番号>` |
| 範囲外の課題の起票 | 下書きを示し、承認後にNotionへタスクを作る | 下書きを示し、承認後に`gh issue create` |
