---
name: bug-investigation-workflow
description: Use when starting work on a bug/defect task — either a Notion task whose `種類` property is `Issue (Fix)`, or an ad-hoc bug the user describes to investigate and fix. Covers root-cause investigation (including checking whether it's already been fixed upstream since the issue was filed), impact-scoped fix planning, implementation, and self-review; testing, `notion-task-workflow` handoff, and PR draft prep are delegated to `dev-workflow-shared`.
---

# Bug Investigation Workflow

不具合の原因調査から修正・テスト・PR下書き作成までを支援する。事前準備・テスト実行・`notion-task-workflow`への橋渡し・PR下書き作成は`dev-workflow-shared` Skillに委譲する(`implementation-workflow`と共通のため)。

## 前提

- 対象は、Notionタスクの`種類`が`Issue (Fix)`のもの、またはユーザーから直接依頼された不具合調査
- 実装の進め方は、このdotfilesの`~/.claude/CLAUDE.md`の「コーディング」節に従う: 既存コードのスタイル・流用できるものをまず調べる、コメントは「why」のみ簡潔に

## 事前準備

`dev-workflow-shared`の「事前準備: リポジトリの最新化確認」を実行する。

## 原因調査(再現・切り分け)

1. Notionタスクページの内容(現象の説明、`何のため？`/`タスクのゴール`等)を確認し、不具合の現象と期待動作を把握する
2. 可能であれば現象を再現する(再現手順の確認・実行)
3. 関連するコード箇所を特定する
4. 特定したコード箇所について、そのNotionタスクの`Created time`(Issue登録日時)以降の本流ブランチでの変更履歴を確認する(例: `git log --since="<Created time>" -- <path>`)。Issue登録後に別の変更で既に修正されている可能性があるため
   - 変更履歴から解消済みの可能性が高いと判断した場合、コミットメッセージや差分だけで断定せず、可能であれば現象を確認するテスト(再現手順の再実行、または該当のユニットテストの追加・実行)で裏付けを取る
   - テストで解消を確認できた場合は、その旨をユーザーに報告し、それ以上の修正作業は行わない
5. 4で未解消と確認できた場合、原因を特定する

## 修正方針の提示・承認

1. 特定した原因に対する修正方針を立てる
2. 修正が影響する範囲(呼び出し元・関連機能・依存している他モジュール)を確認し、その変更によって副作用や既存機能とのデグレ(背反)が起きないかを検討する
3. 2で確認した影響範囲を踏まえて、テスト方針(修正の正しさと非デグレの両方をどう確認するか)を立てる。不具合の性質によってはユニットテストだけでなく、シミュレーションによる結合テスト・実機での最終確認まで必要になる場合があるため、どこまでの範囲(ユニット/シミュレーション/実機)で確認するかを明確にする
4. 原因・修正方針・影響範囲・テスト方針をユーザーに提示し、承認を得る(`~/dotfiles/claude/rules/write-approval.md`参照)。承認を得てから実装に進む

## 実装・自己レビュー

1. 承認された修正方針に沿って実装する。既存コードのスタイル・命名規則に合わせ、流用できる既存の関数・ユーティリティがあれば新規実装せずそれを使う
2. 修正は原因に対して必要最小限にとどめる。承認された影響範囲を超える変更が必要になった場合は、その旨をユーザーに報告し、方針の見直しを確認する
3. diffを見直し、意図しない変更(デバッグ用の記述の残存、無関係な差分など)が混入していないか自己レビューする

## テスト以降

自己レビューが終わったら、以下を`dev-workflow-shared`のセクションに沿って実行する。原因調査ステップで確認した再現手順の再実行が、テストの確認対象になる。

1. 「テスト実行」
2. 「`notion-task-workflow`への橋渡し」
3. 「PR下書き作成」
