---
name: pr-task-planning
description: Use as a sub-step of `daily-task-workflow`'s candidate-selection step, or of `pr-workflow`'s own PR/review listing steps, to get the user's open PRs and assigned reviews needing attention today, listed and roughly prioritized. Not typically invoked directly by the user.
---

# PR Task Planning

`daily-task-workflow`のサブワークフロー1、および`pr-workflow`(「自分が出したPRの一覧・優先度整理」「自分にアサインされたレビューの一覧・優先度整理」)から呼ばれる、PR対応・レビューの一覧・優先度整理のみを行うSkill。個別PRのレビュー実施・下書き作成・マージ可否チェックなどは`pr-workflow` Skillが扱う(ここでは行わない)。

## 前提

- `gh search prs`は複数リポジトリを横断して検索できる。`--json`で取れるのは`number, repository, title, url, isDraft, updatedAt`等の概要まで。CI・レビュー・diffサイズなどの詳細は対象を絞った後に`gh pr view <number> --repo <owner/repo> --json ...`で個別取得する
- 複数PRについて`gh pr view`を取得する場合、`for`ループでシェル側にまとめて実行しない。ループ構文自体が承認対象になり、中身が全てread-onlyでも毎回確認を求められるため。PRごとに個別のBashコマンドとして(可能なら1メッセージ内で並列に)実行する
- `gh pr view`の生JSON(特に`statusCheckRollup`・`reviews`)は大きいので、下記のように`--jq`で必要な形に圧縮して取得する

## 自分が出したPRの一覧・優先度整理

1. 一覧を1回で取得する(状態別に複数回検索すると、条件に当てはまらないPRの漏れや複数カテゴリへの重複が出るため)

   ```bash
   gh search prs --author @me --state open --json number,repository,title,url,isDraft,updatedAt
   ```

2. 各PRの状態を圧縮して取得する(`latestReviews`でレビュアーごとの最新状態を直接得る)

   ```bash
   gh pr view <number> --repo <owner/repo> --json isDraft,reviewDecision,mergeStateStatus,statusCheckRollup,latestReviews,reviewRequests,comments --jq '{draft:.isDraft, decision:.reviewDecision, merge:.mergeStateStatus, checks:([.statusCheckRollup[] | if (.conclusion // "") != "" then .conclusion else (.state // .status) end] | group_by(.) | map({key:.[0], value:length}) | from_entries), reviewers:([.latestReviews[] | {(.author.login): .state}] | add), pending:[.reviewRequests[] | .login // .name], comments:(.comments | length)}'
   ```

3. `comments`が1件以上あるPRだけ`--json comments`で本文を取得して要約する。特にユーザー自身が「修正します」のように対応を約束した発言は控えておく(マージ可否チェックで使う)
4. `references/priority-criteria.md`の分類順に照らして、各PRを最初に該当したカテゴリ1つに入れ、カテゴリ順に一覧表示する

## 自分にアサインされたレビューの一覧・優先度整理

1. 一覧を取得する。更新が古い順 = 待たせている順に並ぶ

   ```bash
   gh search prs --review-requested @me --state open --sort updated --order asc --json number,repository,title,url,isDraft,updatedAt
   ```

2. 各PRのサイズと変更ファイルを、新規追加と既存ファイルの変更に分けて取得する(`pr-workflow`のレビュー深さの判定にもそのまま使う。`gh pr view`の`files`には追加/変更の区別が無いためGraphQLを使う)

   ```bash
   gh api graphql -F owner=<owner> -F name=<repo> -F number=<number> -f query='query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){pullRequest(number:$number){additions deletions files(first:100){nodes{path changeType additions deletions}}}}}' --jq '.data.repository.pullRequest | {additions, deletions, added:[.files.nodes[] | select(.changeType == "ADDED") | .path], modified:[.files.nodes[] | select(.changeType != "ADDED") | {path, lines:(.additions + .deletions)}]}'
   ```

3. 自分がレビュー済みで、レビュー後に動きがあったPRを取得する(レビューを送信すると1の一覧から外れ、作成者が返信・修正しても戻らないため)。1の一覧にあるものは除く

   ```bash
   gh search prs --reviewed-by @me --state open --json number,repository,title,url,updatedAt -- -author:@me
   ```

4. 3の各PRに以下を実行し、`newCommits`が`true`(レビュー後にコミットが積まれた)、`repliedThreads`が空でない(自分のスレッドに自分の最終発言より後の返信がある。resolve済みも含む)、`authorComments`が1以上(会話欄に作成者の発言がある)のいずれかに当たるものを再レビュー候補とする。どれにも当たらないもの(作成者がまだ返信していない等)は出さない

   ```bash
   gh api graphql -F owner=<owner> -F name=<repo> -F number=<number> -f query='query($owner:String!,$name:String!,$number:Int!){viewer{login} repository(owner:$owner,name:$name){pullRequest(number:$number){author{login} headRefOid latestReviews(first:50){nodes{author{login} commit{oid}}} reviews(last:50){nodes{author{login} submittedAt}} reviewThreads(first:100){nodes{path first:comments(first:1){nodes{author{login}}} last:comments(last:1){nodes{author{login} createdAt}}}} comments(last:50){nodes{author{login} createdAt}}}}}' --jq '.data.viewer.login as $me | .data.repository.pullRequest | .author.login as $author | ([.reviews.nodes[] | select(.author.login == $me) | .submittedAt] + [.comments.nodes[] | select(.author.login == $me) | .createdAt] | max) as $myLast | {newCommits:(([.latestReviews.nodes[] | select(.author.login == $me) | .commit.oid] | first) != .headRefOid), repliedThreads:[.reviewThreads.nodes[] | select(.first.nodes[0].author.login == $me and .last.nodes[0].author.login != $me and .last.nodes[0].createdAt > $myLast) | .path], authorComments:([.comments.nodes[] | select(.author.login == $author and .createdAt > $myLast)] | length)}'
   ```

5. 「待ち時間が長いもの」「差分が小さく着手しやすいもの」を優先候補として提示し、再レビュー候補は該当理由(コミット追加/スレッド返信/会話欄の返信)を添えて別枠で並べる
