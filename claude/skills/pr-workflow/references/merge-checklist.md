# マージ可否チェックリスト

`pr-workflow`の「マージ可否チェック」から参照される、判定観点。

- `reviewDecision`が`APPROVED`
- `statusCheckRollup`が全て成功
- `mergeStateStatus`が`CLEAN`(コンフリクトなし)
- 未解決のレビュースレッドが残っていない(`gh pr view`では取れないため、`pr-workflow`の「前提」にあるGraphQLクエリで確認する。`isOutdated`のスレッドも未解決なら対象)
- `latestReviews`を確認し、コメントのみで承認していないレビュアーが残っていないか(`reviewDecision`は必須承認数の充足を見ているだけで、全員の承認を意味しない)
- `comments`の中でユーザー自身が対応を約束した発言があれば、それが実際にコミットへ反映されているか(コメント日時と最新コミット日時、diffの内容を突き合わせて確認する)
