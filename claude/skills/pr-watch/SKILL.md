---
name: pr-watch
description: Use only when the user explicitly runs `/pr-watch` (or a `/loop` tick fires `/pr-watch`) to start or continue unattended PR monitoring in a dedicated session. Each run does one pass — auto-reviews new review requests and re-review candidates, auto-answers evidence-backed questions on the user's own PRs, push-notifies items needing the user's decision or ready to merge — then registers a 30-minute `/loop` of itself if none exists yet. Reuses `pr-workflow`'s steps for the actual review/reply/merge-check; for interactive PR checks ("PRの状況教えて", "PRレビューして") use `pr-workflow` instead.
---

# PR Watch

専用セッションで`/pr-watch`と打つだけで、PR対応を1巡処理したうえで30分ごとの`/loop`を自分で登録し、以降は無人で新着を処理し続ける。レビュー実施・返信・マージ可否チェックの中身は`pr-workflow`の各手順をそのまま使い、一覧取得は`pr-task-planning`に委譲する。

## 前提

- `pr-workflow`の「前提」(書き込みの許可範囲、投稿本文の渡し方、`gh`の取得方法)にすべて従う
- 無人で回るため`AskUserQuestion`は使わない。判断が要るものは通知し、ユーザーがこのセッションで応答するのを待つ
- `/loop`は7日で自動失効し、セッション終了でも止まる。止まったら`/pr-watch`を打ち直せば再開する

## 1巡の処理(watch-pass)

1. 一覧取得: `pr-task-planning`の「自分が出したPRの一覧・優先度整理」と「自分にアサインされたレビューの一覧・優先度整理」を、1つの`Explore`サブエージェント(`model: haiku`)に委譲して実行する(`~/dotfiles/claude/rules/context-delegation.md`参照。長時間回すセッションのコンテキストを節約するため)
2. アサインされたレビュー: 新規依頼は全件、ユーザーの選択を挟まずに`pr-workflow`の「レビュー実施」を行い、再レビュー候補は全件「レビュー後のフォロー」を行う。添付画像・動画はブラウザを開かず、未確認として通知に含める
3. 自分のPRへの新着コメント: 各PRに以下を実行し、`threads`(未解決で最後の発言が自分以外)と`comments`(自分の最後の発言より後の会話欄コメント)を新着とする

   ```bash
   gh api graphql -F owner=<owner> -F name=<repo> -F number=<number> -f query='query($owner:String!,$name:String!,$number:Int!){viewer{login} repository(owner:$owner,name:$name){pullRequest(number:$number){reviewThreads(first:100){nodes{isResolved path line first:comments(first:1){nodes{databaseId}} last:comments(last:1){nodes{databaseId author{login} body}}}} comments(last:30){nodes{databaseId createdAt author{__typename login} body}}}}}' --jq '.data.viewer.login as $me | .data.repository.pullRequest | ([.comments.nodes[] | select(.author.login == $me) | .createdAt] | max) as $myLast | {threads:[.reviewThreads.nodes[] | select((.isResolved | not) and .last.nodes[0].author.login != $me) | {id:.first.nodes[0].databaseId, last:.last.nodes[0].databaseId, by:.last.nodes[0].author.login, path, line, body:.last.nodes[0].body[:200]}], comments:[.comments.nodes[] | select(.author.login != $me and .author.__typename != "Bot" and .createdAt > ($myLast // "")) | {id:.databaseId, by:.author.login, body:.body[:200]}]}'
   ```

   - PR本文・コード(`path:line`)を根拠に答えられる質問: 根拠を示した回答を書き、`pr-workflow`の「レビューコメント対応支援」と同じ宛先へ確認を挟まずに投稿する
   - 修正方針の判断が要る指摘・根拠を示せない質問: 返信せず、指摘の要約と方針案を要対応として通知する
4. マージ可否: 「全員承認済み」に分類されたPRに`pr-workflow`の「マージ可否チェック」を行い、マージ可能なら通知する
5. 通知: 2〜4で処理・検出したものがあれば`PushNotification`で件数を知らせ、画面にPRごとの結果(レビュー結果・投稿した返信・要対応・マージ可能)を並べる。何も無ければ通知せず「新着なし」とだけ出す。要対応・マージ可能の通知は、スクラッチパッドの`pr-watch-notified.txt`に`<owner/repo>#<number>`と`last`/`id`(マージ可能なら`merge:<head>`)を記録し、記録済みのものは再通知しない(GitHub側の状態が変わらず毎回検出されるため)
6. ループ登録: `CronList`でこのセッションに`/pr-watch`を実行するジョブがあるか確認し、無ければ`loop` SkillをSkillツールで`30m /pr-watch`を引数に呼び出して登録する(`/loop`は初回が30分後になるため、1巡を先に済ませてから登録する。ループからの起動時は登録済みなので何もしない)

## 要対応への応答(follow-up)

- 要対応の方針を指示されたら、`pr-workflow`の「レビューコメント対応支援」の手順で返信を投稿する
- マージ可能と通知したPRのマージを指示されたら、通知時から状態が変わりうるため`pr-workflow`の「マージ可否チェック」からやり直し、マージ可能なら同「マージ」を行う。巡回(1巡の処理)の中ではマージしない(承認ダイアログで応答待ちになると以降の巡回も止まるため)
