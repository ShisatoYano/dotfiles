---
name: pr-task-planning
description: Use as a sub-step of `pr-workflow`'s or `pr-watch`'s PR/review listing steps to get the user's open PRs and assigned reviews in the current repository and its submodules (or every repository on request), listed and roughly prioritized. Not typically invoked directly by the user.
---

# PR Task Planning

`pr-workflow`(「自分が出したPR」「自分にアサインされたレビュー」の一覧)と`pr-watch`から呼ばれる、PR対応・レビューの一覧・優先度整理のみを行うSkill。個別PRのレビュー実施・下書き作成・マージ可否チェックなどは`pr-workflow` Skillが扱う(ここでは行わない)。

## 前提

- 一覧は`bash ~/.claude/skills/pr-task-planning/scripts/pr-scope.sh` `list`で取得する(LLMを使わずに絞り込むため)。対象は作業ディレクトリのgitリポジトリと、`.gitmodules`のサブモジュールのリポジトリ。gitリポジトリの外か、ユーザーが全プロジェクトを求めたときは`list --all`で全リポジトリを対象にする。出力のJSONは`mine`(自分のPR)・`review_requested`(レビュー依頼)・`reviewed_by`(レビュー済みで、レビュー依頼に無いもの)・`others`(対象外の件数)を持つ。`truncated`に名前が入った一覧は検索の上限に達して欠けている可能性があり、`note`があれば全体を対象にした理由なので、どちらもユーザーに伝える
- 一覧の最後に、対象外の件数を「対象外: 自分のPR N件・レビュー依頼 M件」の1行で添える(中身は出さない)
- 一覧で取れるのは`number, repo, title, url, isDraft, updatedAt`の概要まで。CI・レビュー・diffサイズなどの詳細は対象を絞った後に`gh pr view <number> --repo <owner/repo> --json ...`で個別取得する
- 複数PRについて`gh pr view`を取得する場合、`for`ループでシェル側にまとめて実行しない。ループ構文自体が承認対象になり、中身が全てread-onlyでも毎回確認を求められるため。PRごとに個別のBashコマンドとして(可能なら1メッセージ内で並列に)実行する
- `gh pr view`の生JSON(特に`statusCheckRollup`・`reviews`)は大きいので、下記のように`--jq`で必要な形に圧縮して取得する

## 自分が出したPRの一覧・優先度整理

1. 一覧は`list`の`mine`を使う(状態別に検索し直すと、条件に当てはまらないPRの漏れや複数カテゴリへの重複が出るため)

2. 各PRの状態を圧縮して取得する(`latestReviews`でレビュアーごとの最新状態を直接得る)

   ```bash
   gh pr view <number> --repo <owner/repo> --json isDraft,reviewDecision,mergeStateStatus,statusCheckRollup,latestReviews,reviewRequests,comments --jq '{draft:.isDraft, decision:.reviewDecision, merge:.mergeStateStatus, checks:([.statusCheckRollup[] | if (.conclusion // "") != "" then .conclusion else (.state // .status) end] | group_by(.) | map({key:.[0], value:length}) | from_entries), reviewers:([.latestReviews[] | {(.author.login): .state}] | add), pending:[.reviewRequests[] | .login // .name], comments:(.comments | length)}'
   ```

3. `comments`が1件以上あるPRだけ`--json comments`で本文を取得して要約する。特にユーザー自身が「修正します」のように対応を約束した発言は控えておく(マージ可否チェックで使う)
4. `references/priority-criteria.md`の分類順に照らして、各PRを最初に該当したカテゴリ1つに入れ、カテゴリ順に一覧表示する

## 自分にアサインされたレビューの一覧・優先度整理

1. 一覧は`list`の`review_requested`を使う。更新が古い順 = 待たせている順に並んでいる

2. 各PRのサイズと変更ファイルを、新規追加と既存ファイルの変更に分けて取得する(`pr-workflow`のレビュー深さの判定にもそのまま使う。`gh pr view`の`files`には追加/変更の区別が無いためGraphQLを使う)

   ```bash
   gh api graphql -F owner=<owner> -F name=<repo> -F number=<number> -f query='query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){pullRequest(number:$number){additions deletions files(first:100){nodes{path changeType additions deletions}}}}}' --jq '.data.repository.pullRequest | {additions, deletions, added:[.files.nodes[] | select(.changeType == "ADDED") | .path], modified:[.files.nodes[] | select(.changeType != "ADDED") | {path, lines:(.additions + .deletions)}]}'
   ```

3. 自分がレビュー済みのPRは`list`の`reviewed_by`を使う(レビューを送信すると1の一覧から外れ、作成者が返信・修正しても戻らないため。1の一覧にあるものは除いてある)

4. 3の各PRに以下を実行し、`newCommits`が`true`(レビュー後にコミットが積まれた)、`repliedThreads`が空でない(自分のスレッドに自分の最終発言より後の返信がある。resolve済みも含む)、`authorComments`が1以上(会話欄に作成者の発言がある)のいずれかに当たるものを再レビュー候補とする。どれにも当たらないもの(作成者がまだ返信していない等)は出さない

   ```bash
   gh api graphql -F owner=<owner> -F name=<repo> -F number=<number> -f query='query($owner:String!,$name:String!,$number:Int!){viewer{login} repository(owner:$owner,name:$name){pullRequest(number:$number){url author{login} headRefOid latestReviews(first:50){nodes{author{login} commit{oid}}} reviews(last:50){nodes{author{login} submittedAt}} reviewThreads(first:100){nodes{path first:comments(first:1){nodes{author{login}}} last:comments(last:1){nodes{author{login} createdAt}}}} comments(last:50){nodes{author{login} createdAt}}}}}' --jq '.data.viewer.login as $me | .data.repository.pullRequest | .author.login as $author | ([.reviews.nodes[] | select(.author.login == $me) | .submittedAt] + [.comments.nodes[] | select(.author.login == $me) | .createdAt] | max) as $myLast | {pr:.url, newCommits:(([.latestReviews.nodes[] | select(.author.login == $me) | .commit.oid] | first) != .headRefOid), repliedThreads:[.reviewThreads.nodes[] | select(.first.nodes[0].author.login == $me and .last.nodes[0].author.login != $me and .last.nodes[0].createdAt > $myLast) | .path], authorComments:([.comments.nodes[] | select(.author.login == $author and .createdAt > $myLast)] | length)}'
   ```

5. 「待ち時間が長いもの」「差分が小さく着手しやすいもの」を優先候補として提示し、再レビュー候補は該当理由(コミット追加/スレッド返信/会話欄の返信)を添えて別枠で並べる
