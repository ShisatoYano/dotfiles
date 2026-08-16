---
name: notion-task-planning
description: Use as a sub-step of `daily-task-planning` to select candidate Notion tasks for today within a given work-day budget. Not typically invoked directly by the user.
---

# Notion Task Planning

`daily-task-planning`のサブワークフロー2から呼ばれる、指定された予算(人日)に収まるところまでNotionタスクを選定するのみを行うSkill。タスクページへの進捗記録・完了処理・終業まとめは`notion-task-workflow` Skillが扱う(ここでは行わない)。

## 前提

- Notionへのアクセスは公式リモートMCP(`mcp__notion__*`ツール)経由で行う。専用スクリプトは使わない。MCPサーバーが未登録の場合は`claude mcp add --transport http notion https://mcp.notion.com/mcp --scope user`の実行を、登録済みだが未認証の場合は`/mcp`での認証をユーザーに促す
- タスクDB(担当者・優先度・見積・期限・ステータスのプロパティ。`種類`が`Issue (Fix)`の場合は不具合系タスク)のURL/データソースIDや、`担当者`が自分に絞られたビューのURLはこのSkillにハードコードしない。過去に確認済みならAIメモリを参照し、未確認ならユーザーに確認するかNotion検索で探す
- `見積`はTシャツサイズ(XS〜3XL)で、人日換算は以下を使う: XS(~4h)=0.5日 / S(~1d)=1日 / M(~3d)=3日 / L(~1w)=5日 / 2L(~2w)=10日 / 3L(~3w)=15日 / XL(~1m)=20日 / 2XL(~1.5m)=30日 / 3XL(~2m)=40日(1週=5営業日、1ヶ月=20営業日換算)。同名の`工数`formulaプロパティはSQLクエリ対象外のため使わない

## 手順

1. `nb search --path` などで`work` notebook(`notion-task-workflow` Skillが書き出す)内の直近の`daily/*.md`を確認し、前日までの持ち越し・未完了タスクがあれば把握する
2. 自分の未完了タスクの一覧を取得する。ユーザーが用意した「自分のタスク」ビューがあればそれを`query_data_sources`(view mode)で取得する。無ければ、タスクDBを`担当者`に自分を含む条件で検索する
3. `担当者`が複数人いるタスクは、`見積`をそのまま自分の工数として使わない(見積はタスク全体の工数で、自分の持ち分ではないため)。該当タスクは都度、今日実際に割く時間をユーザーに確認し、その値を4以降で使う
4. 各タスクの`見積`(3で確認した複数担当者タスクは確認済みの時間)を人日換算し、以下の目安で並び替えの一次案を作る(機械的な絶対順位ではなく判断材料として扱う):
   - `ステータス`が`Doing`(着手済み)のタスクは基本的に他より優先するが、絶対ではない
   - 次点は以下の2グループを**同格**として扱う(どちらかを機械的に優先しない): (a) `期限`があるタスクを期限昇順・優先度順に並べたもの、(b) `期限`が未設定でも`種類`が`Issue (Fix)`かつ`優先度`が`Highest`のタスク
   - 上記以外(期限なし・Issueでもない)は優先度順で最後に並べる
5. 4の一次案から、見積(人日換算)の累計が指定された予算に収まるところまでを候補としてリストアップする
