---
name: pr-workflow
description: Use when the user wants to check on their own open pull requests (status, CI, review feedback, merge readiness) or on pull requests assigned to them for review (triage, review support, follow-up). Trigger on phrases like "PRの状況教えて", "自分のPRどうなってる", "レビュー待ちのPRある?", "アサインされてるレビュー確認して", "PRレビューして", "マージしていいか確認して". This skill only produces summaries, prioritized lists, and draft text — it never runs commands that change PR state (merge, approve/request-changes, posting comments); the user always performs those actions themselves.
---

# PR Workflow

このdotfilesの `prs` エイリアス(`shell/aliases.sh`)は `gh search prs --author @me` / `--review-requested @me` で自分のPRと担当レビューを横断的に一覧表示する。このSkillはその発展形で、状況ごとの分類・優先度整理・下調べを行う。

PRの状態を変更する操作(`gh pr merge`、`gh pr review`、`gh pr comment`)はhook(`claude/hooks/block-pr-write-actions.py`)でシステム的にブロックされている。このSkillが行うのは判断材料の整理と下書き作成までであり、実際の操作は必ずユーザー自身が行う。

ユーザーがどちらか一方だけを指定した場合(「自分のPRの状況教えて」「レビュー待ちのPRある?」など)はそのワークフローだけを、このセッション内で直接行う。

両方確認したい場合や、特に指定がなくこのSkillを起動した場合は、2つのワークフローを並列に進めるため、それぞれ専用のHerdrエージェントに委譲する。どちらも調査・下書き作成のみでファイル編集を伴わないため、worktree/branchを作る`herdr-task-launch.sh`(実装タスク向け)ではなく、`scripts/herdr-agent-launch.sh`(ブランチなしのplain workspaceを作るだけの版)を使う。

1. `ListAgents`でこのセッション自身の名前(委譲先からの通知の宛先)を確認する
2. 対象リポジトリ(このセッションの`$PWD`をデフォルトとする)に対して、以下2つを1メッセージ内で並列Bashツール呼び出しとして起動する
   ```
   scripts/herdr-agent-launch.sh <repo_root> pr-own-check "自分のPR確認" "<初期プロンプトA>"
   scripts/herdr-agent-launch.sh <repo_root> pr-review-check "アサインされたレビュー確認" "<初期プロンプトB>"
   ```
   初期プロンプトは以下を骨子とする。トリガー文言をそのまま使うことで、委譲先セッションはこのSkillの該当ワークフローだけを自然に実行する。報告は「確認完了」と「その日のクローズ」の2回で、後者は実対応が終わった場合・先送りされた場合のどちらでも同じ扱いとする(分岐を増やすと委譲先ごとに解釈がぶれるため、シンプルに統一する)。
   - 初期プロンプトA: 「自分のPRの状況を確認してください。確認が終わり結果を提示したら、SendMessageツールで`to: "<親セッション名>"`宛に確認完了(概要つき)を報告してください。その後、提示した内容(マージ・コメント返信・承認など)への対応をユーザーがその日のうちに行うか確認し、対応が完了した場合・『今日は対応しない』等その日は対応しないとされた場合のいずれでも、その時点で同じ宛先にクローズ報告(実施済みか先送りかの別と概要つき)をしてください。」
   - 初期プロンプトB: 「アサインされているレビューを確認して支援してください。確認が終わり結果を提示したら、SendMessageツールで`to: "<親セッション名>"`宛に確認完了(概要つき)を報告してください。その後、提示した内容(レビュー投稿など)への対応をユーザーがその日のうちに行うか確認し、対応が完了した場合・『今日は対応しない』等その日は対応しないとされた場合のいずれでも、その時点で同じ宛先にクローズ報告(実施済みか先送りかの別と概要つき)をしてください。」
3. 起動結果(スクリプトが返すJSON)をユーザーに提示する。以降の進捗は、Herdr側のTUIと、委譲先からの2回の通知(SendMessage: ①確認作業完了 ②その日のクローズ)で把握する。委譲後はこのセッションで他の作業を並行して進めてよい。通知を受け取ったら、`workspace_id`(2の起動結果に含まれる)とあわせて概要を記録しておく。その日の作業記録としてユーザーに後でまとめて報告できるようにするためと、`notion-task-workflow`の終業時のまとめでクローズ済みペインを削除する際に使うため
4. 委譲後にユーザーから進捗を聞かれた場合は、通知をポーリングで待つのではなく、その時点で`herdr agent get pr-own-check`/`herdr agent get pr-review-check`で状態(idle/working/blocked)を、必要なら`herdr pane read <pane_id>`で直近の出力を確認して報告する

## 共通の使い方

`gh search prs` は複数リポジトリを横断して検索できる。フィルタとして以下が使える。

- `--checks {pending|success|failure}` — CI状況
- `--review {none|required|approved|changes_requested}` — レビュー状況
- `--draft` — draft PRの絞り込み
- `--sort updated --order asc` — 更新が古い順(=放置されているもの)に並べる

`--json` で取れるのは `assignees, author, authorAssociation, body, closedAt, commentsCount, createdAt, id, isDraft, isLocked, isPullRequest, labels, number, repository, state, title, updatedAt, url` まで。CI詳細・レビュー内容・diffサイズ・マージ可否などPR個別の深い情報は含まれないので、対象PRを絞り込んだ後に `gh pr view <number> --repo <owner/repo> --json ...` で個別取得する。

複数PRについてこれを行う場合、`for`ループでシェル側にまとめて実行させない。`gh pr view`単体はClaude Codeのネイティブな読み取り専用コマンドとして自動的に承認されるが、`for`ループで包むとループ構文(変数展開・複数文)自体が承認対象になり、中身が全てread-onlyでも毎回確認を求められてしまう。PRごとに個別のBashコマンドとして(可能なら1メッセージ内で並列に)実行する。

## 自分が出したPRのワークフロー

### 1. 状況の一覧・優先度整理

`pr-task-planning`の「自分が出したPRの一覧・優先度整理」を実行する。

### 2. レビューコメントへの対応支援

対象PRについて `gh pr view <number> --repo <owner/repo> --json reviews,comments,url` を取得する(インラインの行コメントも見たい場合は `gh api repos/<owner>/<repo>/pulls/<number>/comments`)。指摘をファイル/観点ごとにグルーピングして要約し、それぞれについて「何を指摘されているか」「対応方針の提案」「返信文の下書き」を提示する。**投稿は行わない。**

### 3. マージ可否チェック

対象PRについて `gh pr view <number> --repo <owner/repo> --json reviewDecision,statusCheckRollup,mergeStateStatus,mergeable,reviews,comments` を取得し、以下を確認して結論(マージ可能 / まだ対応が必要:理由)を提示する。

- `reviewDecision` が `APPROVED`
- `statusCheckRollup` が全て成功
- `mergeStateStatus` が `CLEAN`(コンフリクトなし)
- 未解決のレビュースレッドが残っていない
- `reviews` を個別に確認し、コメントのみで承認していないレビュアーが残っていないか(`reviewDecision`は必須承認数の充足を見ているだけで、全員の承認を意味しない)
- `comments` の中でユーザー自身が対応を約束した発言があれば、それが実際にコミットへ反映されているか(コメント日時と最新コミット日時、diffの内容を突き合わせて確認する)

## 自分にアサインされたレビューのワークフロー

### 1. レビュー待ちPRの一覧・優先度整理

`pr-task-planning`の「自分にアサインされたレビューの一覧・優先度整理」を実行する。

### 2. レビュー実施そのものの支援

対象PRの `body`(`gh pr view <number> --repo <owner/repo> --json body` などで取得済みのもの)に、画像・動画の添付を示すパターン(`https://github.com/user-attachments/assets/...` へのリンクや、Markdownの画像記法 `![...](...)`)が含まれていないか確認する。含まれていた場合は、その内容を読み取ることはできない(特に動画は視聴できない)ので、代わりに `gh pr view <number> --repo <owner/repo> --web` でPRページをブラウザで自動的に開き、「添付画像/動画があるためブラウザを開きました。内容をご確認ください」とユーザーに伝える。

レビュー対象が複数ある場合は、PRごとに逐次処理せず、**Agentツール(`general-purpose`)でPRごとに並行してサブエージェントを立てる**(1メッセージにまとめて複数のAgent呼び出しを行う)。各サブエージェントには対象のPR番号・リポジトリを渡し、以下を行わせる。

1. 対象PRの既存レビュー・コメント(`gh pr view <number> --repo <owner/repo> --json reviews,comments`、インラインの行コメントは`gh api repos/<owner>/<repo>/pulls/<number>/comments`)を取得する
2. `review` Skillを呼び出して本体のコードレビュー(diff要約・観点出し・リスク箇所の指摘)を行わせる
3. 出てきた指摘を1の既存コメントと突き合わせる: 重複しかつその後のコミットで対応済みのものは除外、重複するが未対応のものは詳細を再掲せず「(誰が)指摘済み・未対応」の一言に圧縮、既存コメントに無い新規の指摘は詳しく残す(他レビュアーの指摘の焼き直しにならないようにするため)
4. 全体としてapprove相当か変更要求相当かコメントに留めるべきかの推奨と、実際に投稿する場合のレビューコメント文面の下書きをまとめて返す

全サブエージェントの結果が揃ってから、PRごとの結果をまとめて1つのレポートとしてユーザーに提示する。

### 3. レビュー後のフォロー

レビュー済みのPRについて `gh pr view <number> --repo <owner/repo> --json reviews,commits,updatedAt` を確認し、レビュー後に新しいコミットが積まれているか・指摘内容が実際に反映されているかを見て、再レビューが必要そうなものを一覧化して提示する。

### 4. 確認漏れの再チェック

一覧にあったPRを一通り確認し終えたら、最後にステップ1と同じクエリをもう一度実行する。

```bash
gh search prs --review-requested @me --state open --sort updated --order asc
```

対応済みのPRが一覧から消えていることを確認しつつ、確認作業をしている間に新しく追加されたレビュー依頼が無いかをチェックする。新規のものが見つかった場合はユーザーに知らせ、続けて確認するか尋ねる。

## 補足

- `gh` CLIが必要(このdotfilesの `scripts/setup.sh` でインストール済み)
- 複数リポジトリを横断する場合は `gh search prs`、特定PRの詳細は `gh pr view --repo <owner/repo> <number>` を使い分ける
