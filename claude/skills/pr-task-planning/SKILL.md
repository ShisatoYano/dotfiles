---
name: pr-task-planning
description: Use as a sub-step of `daily-task-planning` to get the user's open PRs and assigned reviews needing attention today, listed and roughly prioritized. Not typically invoked directly by the user.
---

# PR Task Planning

`daily-task-planning`のサブワークフロー1から呼ばれる、PR対応・レビューの一覧・優先度整理のみを行うSkill。個別PRのレビュー実施支援・下書き作成・マージ可否チェックなどは`pr-workflow` Skillが扱う(ここでは行わない)。

## 前提

- `gh search prs`は複数リポジトリを横断して検索できる。フィルタ: `--checks {pending|success|failure}`(CI状況)、`--review {none|required|approved|changes_requested}`(レビュー状況)、`--sort updated --order asc`(更新が古い順)
- 複数PRについて`gh pr view`を個別に取得する場合、`for`ループでシェル側にまとめて実行しない。ループ構文自体が承認対象になり、中身が全てread-onlyでも毎回確認を求められるため。PRごとに個別のBashコマンドとして(可能なら1メッセージ内で並列に)実行する

## 自分が出したPRの一覧・優先度整理

まず以下を順に実行し、CI/レビュー状況で粗く分類する。

```bash
gh search prs --author @me --state open --checks failure           # CI失敗中
gh search prs --author @me --state open --review changes_requested # 変更要求あり
gh search prs --author @me --state open --review required          # レビュー待ち
gh search prs --author @me --state open --review approved          # approve済み(マージ判断へ)
```

`reviewDecision`(`--review approved` などの分類の元)は「必須承認数を満たしたか」しか見ていないため、一部のレビュアーがコメントのみで承認していない状態でも `approved` に分類されうる。これを見落とさないよう、各PRについて `gh pr view <number> --repo <owner/repo> --json reviews,comments,reviewRequests` を取得し、

- レビュアーごとの状態(`APPROVED` / `COMMENTED` / `CHANGES_REQUESTED`)を一覧表示する
- 未回答のレビュー依頼(`reviewRequests`)が残っていないか確認する
- PRコメントの有無を確認し、あれば要約する。特にPR作者(ユーザー自身)が「修正します」のように対応を約束している発言があれば控えておく(後続の判断で使うことがある)

これらを踏まえて優先度を判定する。優先度: CI失敗中 → 変更要求あり → 一部レビュアーがコメントのみ・未回答のまま止まっているもの(実質レビュー未完了) → (様子見)レビュー待ち → 全員承認済み。draft PRは参考として別枠で扱う。

## 自分にアサインされたレビューの一覧・優先度整理

```bash
gh search prs --review-requested @me --state open --sort updated --order asc
```

更新が古い順 = 待たせている順に並ぶ。件数が多い場合は `gh pr view <number> --repo <owner/repo> --json additions,deletions` で差分サイズも確認し、「待ち時間が長いもの」「差分が小さく着手しやすいもの」を優先候補として提案する。
