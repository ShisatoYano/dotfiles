---
name: pr-workflow
description: Use when the user wants to check on their own open pull requests (status, CI, review feedback, merge readiness) or on pull requests assigned to them for review (triage, review support, follow-up). Trigger on phrases like "PRの状況教えて", "自分のPRどうなってる", "レビュー待ちのPRある?", "アサインされてるレビュー確認して", "PRレビューして", "マージしていいか確認して". This skill only produces summaries, prioritized lists, and draft text — it never runs commands that change PR state (merge, approve/request-changes, posting comments); the user always performs those actions themselves.
---

# PR Workflow

このdotfilesの `prs` エイリアス(`shell/aliases.sh`)は `gh search prs --author @me` / `--review-requested @me` で自分のPRと担当レビューを横断的に一覧表示する。このSkillはその発展形で、状況ごとの分類・優先度整理・下調べを行う。

**PRの状態を変更する操作(`gh pr merge`、`gh pr review --approve` / `--request-changes` / `--comment`、`gh pr comment` など)は絶対に実行しない。** このSkillが行うのは判断材料の整理と下書き作成までであり、実際の操作は必ずユーザー自身が行う。

## 共通の使い方

`gh search prs` は複数リポジトリを横断して検索できる。フィルタとして以下が使える。

- `--checks {pending|success|failure}` — CI状況
- `--review {none|required|approved|changes_requested}` — レビュー状況
- `--draft` — draft PRの絞り込み
- `--sort updated --order asc` — 更新が古い順(=放置されているもの)に並べる

`--json` で取れるのは `assignees, author, authorAssociation, body, closedAt, commentsCount, createdAt, id, isDraft, isLocked, isPullRequest, labels, number, repository, state, title, updatedAt, url` まで。CI詳細・レビュー内容・diffサイズ・マージ可否などPR個別の深い情報は含まれないので、対象PRを絞り込んだ後に `gh pr view <number> --repo <owner/repo> --json ...` で個別取得する。

## 自分が出したPRのワークフロー

### 1. 状況の一覧・優先度整理

以下を順に実行し、まとめて報告する(対応必須のものを先に出す)。

```bash
gh search prs --author @me --state open --checks failure           # CI失敗中
gh search prs --author @me --state open --review changes_requested # 変更要求あり
gh search prs --author @me --state open --review required          # レビュー待ち
gh search prs --author @me --state open --review approved          # approve済み(マージ判断へ)
```

優先度: CI失敗中 → 変更要求あり → (様子見)レビュー待ち → approve済み。draft PRは参考として別枠で扱う。

### 2. レビューコメントへの対応支援

対象PRについて `gh pr view <number> --repo <owner/repo> --json reviews,comments,url` を取得する(インラインの行コメントも見たい場合は `gh api repos/<owner>/<repo>/pulls/<number>/comments`)。指摘をファイル/観点ごとにグルーピングして要約し、それぞれについて「何を指摘されているか」「対応方針の提案」「返信文の下書き」を提示する。**投稿は行わない。**

### 3. マージ可否チェック

対象PRについて `gh pr view <number> --repo <owner/repo> --json reviewDecision,statusCheckRollup,mergeStateStatus,mergeable` を取得し、以下を確認して結論(マージ可能 / まだ対応が必要:理由)を提示する。

- `reviewDecision` が `APPROVED`
- `statusCheckRollup` が全て成功
- `mergeStateStatus` が `CLEAN`(コンフリクトなし)
- 未解決のレビュースレッドが残っていない

**マージは実行しない。**

## 自分にアサインされたレビューのワークフロー

### 1. レビュー待ちPRの一覧・優先度整理

```bash
gh search prs --review-requested @me --state open --sort updated --order asc
```

更新が古い順 = 待たせている順に並ぶ。件数が多い場合は `gh pr view <number> --repo <owner/repo> --json additions,deletions` で差分サイズも確認し、「待ち時間が長いもの」「差分が小さく着手しやすいもの」を優先候補として提案する。

### 2. レビュー実施そのものの支援

実際にレビューする際は `review` Skillを呼び出して本体のコードレビュー(diff要約・観点出し・リスク箇所の指摘)を行わせる。このSkillはその結果を踏まえて、全体としてapprove相当か変更要求相当かコメントに留めるべきかの整理と、実際に投稿する場合のレビューコメント文面の下書きまでを行う。**`gh pr review` などによる投稿は実行しない。**

### 3. レビュー後のフォロー

レビュー済みのPRについて `gh pr view <number> --repo <owner/repo> --json reviews,commits,updatedAt` を確認し、レビュー後に新しいコミットが積まれているか・指摘内容が実際に反映されているかを見て、再レビューが必要そうなものを一覧化して提示する。

## 補足

- `gh` CLIが必要(このdotfilesの `scripts/setup.sh` でインストール済み)
- 複数リポジトリを横断する場合は `gh search prs`、特定PRの詳細は `gh pr view --repo <owner/repo> <number>` を使い分ける
