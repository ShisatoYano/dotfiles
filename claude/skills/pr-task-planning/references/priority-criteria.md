# PR優先度判定基準

`pr-task-planning`の「自分が出したPRの一覧・優先度整理」から参照される、優先度判定の観点。

## 分類順

上から順に判定し、最初に該当したカテゴリ1つだけに入れる(重複させない)。

1. draft: `draft`が`true`(参考として別枠で表示)
2. CI失敗中: `checks`に`FAILURE`/`CANCELLED`/`TIMED_OUT`/`ERROR`のいずれかがある
3. 変更要求あり: `reviewers`に`CHANGES_REQUESTED`がある
4. 実質レビュー未完了: レビューが1件以上あるが、`pending`に未回答のレビュアーが残っている、または`COMMENTED`のみで承認していないレビュアーがいる
5. CI実行中: `checks`に`PENDING`/`IN_PROGRESS`/`QUEUED`がある(様子見)
6. レビュー待ち: レビューがまだ1件も無い(様子見)
7. 全員承認済み: 上記どれにも該当しない(マージ可否チェックへ)

## 注意

- `reviewDecision`は「必須承認数を満たしたか」しか見ていないため、一部のレビュアーがコメントのみで承認していなくても`APPROVED`になりうる。分類には`reviewers`(`latestReviews`)を使う
