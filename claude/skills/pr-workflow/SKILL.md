---
name: pr-workflow
description: Use when the user wants to check on their own open pull requests (status, CI, review feedback, merge readiness) or to handle pull requests assigned to them for review (triage, code review, re-review follow-up). Trigger on phrases like "PRの状況教えて", "自分のPRどうなってる", "レビュー待ちのPRある?", "アサインされてるレビュー確認して", "PRレビューして", "マージしていいか確認して". Code review runs in one subagent per PR and returns only must-fix findings (with reason and fix) and premise questions as ready-to-post draft comments. This skill never changes PR state (merge, approve/request-changes, posting comments); the user always performs those actions themselves. For a repository that has its own `pr-review` Skill (`.claude/skills/pr-review`), the code review is delegated to that Skill.
---

# PR Workflow

このdotfilesの`prs`エイリアス(`shell/aliases.sh`)の発展形として、自分のPRと担当レビューの分類・優先度整理・レビュー実施・下書き作成を行う。一覧・優先度整理は`pr-task-planning`に委譲し、リポジトリ専用の`pr-review` Skillがあればコードレビューはそちらに委譲する。

## 前提

- PRの状態を変更する操作(`gh pr merge`/`review`/`comment`、およびそれと同等の`gh api`の書き込み・GraphQL mutation)はhook(`claude/hooks/block-pr-write-actions.py`)でブロックされている。行うのは判断材料の整理と下書き作成までで、投稿・approve・マージは必ずユーザー自身が行う
- `gh`の取得方法(`gh search prs`と`gh pr view`の使い分け、`for`ループ禁止、`--jq`での圧縮)は`pr-task-planning`の「前提」に従う
- 未解決のレビュースレッドと自分の最新レビュー時点のコミットは`gh pr view`では取れないため、以下のGraphQLで取得する(以降「レビュー状態クエリ」と呼ぶ)

  ```bash
  gh api graphql -F owner=<owner> -F name=<repo> -F number=<number> -f query='query($owner:String!,$name:String!,$number:Int!){viewer{login} repository(owner:$owner,name:$name){pullRequest(number:$number){headRefOid latestReviews(first:50){nodes{author{login} state commit{oid}}} reviewThreads(first:100){nodes{isResolved isOutdated path line comments(first:1){nodes{author{login} body}}}}}}}' --jq '.data.viewer.login as $me | .data.repository.pullRequest | {head:.headRefOid, myReview:([.latestReviews.nodes[] | select(.author.login == $me) | {state, commit:.commit.oid}] | first), openThreads:[.reviewThreads.nodes[] | select(.isResolved | not) | {by:.comments.nodes[0].author.login, path, line, isOutdated, body:.comments.nodes[0].body[:120]}]}'
  ```

- 対象の決め方: 特に指定が無ければ「自分が出したPR」→「自分にアサインされたレビュー」の順に両方実行する。一方だけ・特定PR1件の指定ならその部分だけ実行する

## 自分が出したPR

1. 一覧・優先度整理: `pr-task-planning`の「自分が出したPRの一覧・優先度整理」を実行する
2. レビューコメント対応支援: 対象PRにレビュー状態クエリを実行し、`openThreads`と`gh pr view --json reviews,comments`の指摘をファイル/観点ごとにまとめ、それぞれ「何を指摘されているか」「対応方針案」「返信文の下書き」を提示する
3. マージ可否チェック: `gh pr view --json reviewDecision,statusCheckRollup,mergeStateStatus,latestReviews,comments`とレビュー状態クエリの結果を`references/merge-checklist.md`の観点に照らし、結論(マージ可能 / 要対応: 理由)を提示する

## 自分にアサインされたレビュー

### 1. 一覧・深さ判定

`pr-task-planning`の「自分にアサインされたレビューの一覧・優先度整理」を実行し、取得したサイズ・変更ファイルから`references/review-criteria.md`の「深さの判定」で各PRの深さを決める。一覧と深さを提示し、どのPRをレビューするかユーザーに選んでもらう。

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
4. 結果の提示: 返ってきたブロックをそのまま並べ、Must・質問があるものを先に出す。【投稿用】の投稿はユーザーが行う(gh-dashの`I`キー等)

### 3. レビュー後のフォロー

1. 自分がレビュー済みで、まだ開いているPRを取得する(レビューを提出すると`--review-requested`の一覧からは外れるため、別に検索する)

   ```bash
   gh search prs --reviewed-by @me --state open -- -author:@me
   ```

2. 各PRにレビュー状態クエリを実行し、`myReview.commit`が`head`と異なる(レビュー後にコミットが積まれた)もの、または自分の`openThreads`が残っているものを再レビュー候補として提示する
3. ユーザーが再レビューを選んだPRは、「レビュー実施」と同じ手順でサブエージェントに委譲する。その際、対象を`gh api -H 'Accept: application/vnd.github.diff' repos/<owner>/<repo>/compare/<myReview.commit>...<head>`の差分に限定し、自分の未解決スレッドの指摘が反映されたかを優先して確認させる

### 4. 確認漏れの再チェック

最後に「一覧・深さ判定」と同じ検索をもう一度実行し、対応済みのPRが消えていること、作業中に新しいレビュー依頼が増えていないかを確認する。新規があればユーザーに知らせ、続けて確認するか尋ねる。
