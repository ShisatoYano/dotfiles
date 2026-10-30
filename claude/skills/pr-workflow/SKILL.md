---
name: pr-workflow
description: Use when the user wants to check on their own open pull requests (status, CI, review feedback, merge readiness) or to handle pull requests assigned to them for review (triage, code review, re-review follow-up). Trigger on phrases like "PRの状況教えて", "自分のPRどうなってる", "レビュー待ちのPRある?", "アサインされてるレビュー確認して", "PRレビューして", "マージしていいか確認して". Code review runs in one subagent per PR, keeps only must-fix findings (with reason and fix) and premise questions, and submits the result automatically as a GitHub review (request-changes / comment / approve). Replies to review comments on the user's own PRs are posted automatically once the user picks the response policy. This skill never merges; the user always merges themselves. For a repository that has its own `pr-review` Skill (`.claude/skills/pr-review`), the code review is delegated to that Skill.
---

# PR Workflow

このdotfilesの`prs`エイリアス(`shell/aliases.sh`)の発展形として、自分のPRと担当レビューの分類・優先度整理・レビュー実施と送信・レビューコメントへの返信を行う。一覧・優先度整理は`pr-task-planning`に委譲し、リポジトリ専用の`pr-review` Skillがあればコードレビューはそちらに委譲する。

## 前提

- PRへの書き込みは`gh api -X POST`の`repos/<owner>/<repo>/pulls/<number>/reviews`(レビュー送信)・`pulls/<number>/comments/<id>/replies`(スレッドへの返信)・`issues/<number>/comments`(会話欄への返信)だけがhook(`claude/hooks/block-pr-write-actions.py`)で許可されている。マージ・`gh pr review`/`comment`・その他の書き込みはブロックされ、マージは必ずユーザー自身が行う
- 投稿する本文はスクラッチパッドのファイルに書いてから`--input <file>`/`-F body=@<file>`で渡す(本文中の文字列がhookに誤検知されず、クォートも崩れないため)。末尾には空行を挟んで`🤖 Generated with [Claude Code](https://claude.com/claude-code)`を付ける(本文を送らない`APPROVE`を除く)
- `gh`の取得方法(`gh search prs`と`gh pr view`の使い分け、`for`ループ禁止、`--jq`での圧縮)は`pr-task-planning`の「前提」に従う
- 未解決のレビュースレッドと自分の最新レビュー時点のコミットは`gh pr view`では取れないため、以下のGraphQLで取得する(以降「レビュー状態クエリ」と呼ぶ)

  ```bash
  gh api graphql -F owner=<owner> -F name=<repo> -F number=<number> -f query='query($owner:String!,$name:String!,$number:Int!){viewer{login} repository(owner:$owner,name:$name){pullRequest(number:$number){headRefOid latestReviews(first:50){nodes{author{login} state commit{oid}}} reviewThreads(first:100){nodes{isResolved isOutdated path line comments(first:1){nodes{databaseId author{login} body}}}}}}}' --jq '.data.viewer.login as $me | .data.repository.pullRequest | {head:.headRefOid, myReview:([.latestReviews.nodes[] | select(.author.login == $me) | {state, commit:.commit.oid}] | first), openThreads:[.reviewThreads.nodes[] | select(.isResolved | not) | {id:.comments.nodes[0].databaseId, by:.comments.nodes[0].author.login, path, line, isOutdated, body:.comments.nodes[0].body[:120]}]}'
  ```

- 対象の決め方: 特に指定が無ければ「自分が出したPR」→「自分にアサインされたレビュー」の順に両方実行する。一方だけ・特定PR1件の指定ならその部分だけ実行する

## 自分が出したPR

1. 一覧・優先度整理: `pr-task-planning`の「自分が出したPRの一覧・優先度整理」を実行する
2. レビューコメント対応支援: 対象PRにレビュー状態クエリを実行し、`openThreads`と`gh pr view --json reviews,comments`の指摘をファイル/観点ごとにまとめ、それぞれ「何を指摘されているか」と対応方針案を提示し、`AskUserQuestion`で方針を選んでもらう。選ばれた方針で返信を書き、確認を挟まずに投稿する(スレッドは`openThreads`の`id`を使い`comments/<id>/replies`へ、会話欄の指摘は`issues/<number>/comments`へ)。修正のpushはユーザーが行うため、返信は「〜で対応します」の形にし、pushされていない修正を「対応しました」と書かない
3. マージ可否チェック: `gh pr view --json reviewDecision,statusCheckRollup,mergeStateStatus,latestReviews,comments`とレビュー状態クエリの結果を`references/merge-checklist.md`の観点に照らし、結論(マージ可能 / 要対応: 理由)を提示する

## 自分にアサインされたレビュー

### 1. 一覧・深さ判定

`pr-task-planning`の「自分にアサインされたレビューの一覧・優先度整理」を実行し、取得したサイズ・変更ファイルから`references/review-criteria.md`の「深さの判定」で各PRの深さを決める。一覧と深さ、別枠の再レビュー候補を提示し、どのPRをレビューするかユーザーに選んでもらう(再レビュー候補を選んだら「レビュー後のフォロー」へ)。

### 2. レビュー実施

対象リポジトリに`pr-review` Skill(`.claude/skills/pr-review`)がある場合はそちらに委譲する。それ以外は対象PRごとに以下を行う。

1. 添付確認: `body`に画像・動画の添付(`https://github.com/user-attachments/assets/...`や`![...](...)`)があれば、Claudeは内容を確認できないため`gh pr view <number> --repo <owner/repo> --web`でブラウザを開き、「添付画像/動画があるためブラウザを開きました。内容をご確認ください」と伝える
2. ローカルクローンの特定: `ghq list -p -e github.com/<owner>/<repo>`で探す(無ければdiffのみでレビューし、未確認に記録させる)
3. サブエージェントへの委譲: diffや周辺コードをメインのコンテキストに載せないよう、1PRにつき1つの`general-purpose`サブエージェントでレビューする。モデルは`references/review-criteria.md`の深さの表に従って指定する。複数PRは1メッセージで並列に起動する(同時3件まで)。ブリーフには以下を含める
   - 対象(`<owner/repo>#<number>`)、深さ、ローカルクローンのパス(または「なし」)
   - `~/.claude/skills/pr-workflow/references/review-criteria.md`を読み、その観点・出力ルール・出力形式に厳密に従うこと
   - diffは`gh pr diff`、既存指摘は上記のレビュー状態クエリと`gh pr view --json body,reviews,comments`で取得すること
   - ローカルクローンは現在のチェックアウトのまま読むだけ(grep・ファイル閲覧)にし、ブランチの切り替えや変更をしないこと(呼び出し元はベース側にあるので現状のチェックアウトで足りる)
   - 見出しのタイトルはPRのタイトルを翻訳・要約せずそのまま書くこと(一覧でPRを見分けられなくなるため)
   - 返答は出力形式のブロックのみとし、調査過程やdiffの引用を含めないこと
4. レビュー送信: 確認を挟まずにPRごとに1回送信する。`references/review-criteria.md`の「送信イベント」でeventを決める。`APPROVE`は指摘なしのときだけなので、`body`(フッターを含む)を付けずに送る。【投稿用】の各項目は、`<path>:<line>`を`comments`の`path`・`line`・`side`(`L<line>`なら`LEFT`、それ以外は`RIGHT`)にし、項目の残りの全文を本文にする。このJSONを`gh api -X POST repos/<owner>/<repo>/pulls/<number>/reviews --input <file>`で送る。`(diff外)`の項目はレビューの`body`に`path:line`付きで入れる。行の指定が原因で422が返ったら、全項目を`body`に移して1回だけ再送する
5. 結果の提示: PRごとに、返ってきたブロック(概要・【投稿用】・【レビュアー向けメモ】)に、送信したeventとレビューのURL(レスポンスの`html_url`)を添えて並べる。REQUEST_CHANGES・COMMENTのものを先に出す。概要はユーザーが自分でもPRを把握するためのものなので省略しない

### 3. レビュー後のフォロー

1. 再レビュー候補は「一覧・深さ判定」で`pr-task-planning`が該当理由付きで出したものを使う(ここで再検索しない)
2. ユーザーが選んだPRは、レビュー状態クエリで`myReview.commit`と`head`を取得し、「レビュー実施」と同じ手順で委譲・送信する。その際、対象を`gh api -H 'Accept: application/vnd.github.diff' repos/<owner>/<repo>/compare/<myReview.commit>...<head>`の差分(コミット追加が無ければ差分なし)に限定し、自分のスレッド・会話欄への作成者の返信と、指摘が反映されたかを優先して確認させる

### 4. 確認漏れの再チェック

最後に「一覧・深さ判定」と同じ検索をもう一度実行し、対応済みのPRが消えていること、作業中に新しいレビュー依頼が増えていないかを確認する。新規があればユーザーに知らせ、続けて確認するか尋ねる。
