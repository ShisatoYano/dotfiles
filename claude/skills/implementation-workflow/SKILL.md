---
name: implementation-workflow
description: Use when starting implementation work on a task — either a Notion task whose `種類` property is `機能追加 (Add)`/`改善 (Change)` (or unset but inferred as implementation work from its title/description), or an ad-hoc implementation request from the user. Covers requirement/design confirmation, impact-scoped implementation planning, implementation, and self-review; testing, `notion-task-workflow` handoff, and PR draft prep are delegated to `dev-workflow-shared`. For a Notion task whose `種類` is `Issue (Fix)`, use `bug-investigation-workflow` instead.
---

# Implementation Workflow

新機能追加・改善などの実装作業を、要件確認からテスト・PR下書き作成まで支援する。事前準備・テスト実行・`notion-task-workflow`への橋渡し・PR下書き作成は`dev-workflow-shared` Skillに委譲する(`bug-investigation-workflow`と共通のため)。

## 前提

- 対象は、Notionタスクの`種類`が`機能追加 (Add)`/`改善 (Change)`などの実装系タスク、または`種類`未設定でタイトル・説明から実装作業と判断できるタスク、あるいはユーザーから直接依頼された実装作業。`種類`が`Issue (Fix)`のタスクは`bug-investigation-workflow`の対象
- 実装の進め方は、このdotfilesの`~/.claude/CLAUDE.md`の「コーディング」節に従う: 既存コードのスタイル・流用できるものをまず調べる、コメントは「why」のみ簡潔に

## 事前準備

`dev-workflow-shared`の「事前準備: リポジトリの最新化確認」を実行する。

## 要件・設計の確認

1. Notionタスクページの内容(`タスクのゴール`、`何のため？`などの説明文)を確認し、実装すべき内容と目的を把握する
2. 実装対象がどのリポジトリ・モジュールにまたがるか整理する(サブモジュール構成のプロジェクトのため)
3. 既存コードを調査し、流用できる実装や類似パターンが無いか確認する(新しく書く前に既存を調べる)
4. 要件・仕様に曖昧な点や決めきれない設計判断があれば、実装に入る前にユーザーに確認する

## 実装方針の提示・承認

1. 要件・設計の確認を踏まえて、実装方針(どう実装するか、どのファイル/モジュールを変更するか)を立てる
2. 実装が影響する範囲(呼び出し元・関連機能・依存している他モジュール)を確認し、その変更によって副作用や既存機能とのデグレ(背反)が起きないかを検討する
3. 2で確認した影響範囲を踏まえて、テスト方針(実装の正しさと非デグレの両方をどう確認するか)を立てる。機能の性質によってはユニットテストだけでなく、シミュレーションによる結合テスト・実機での最終確認まで必要になる場合があるため、どこまでの範囲(ユニット/シミュレーション/実機)で確認するかを明確にする
4. 実装方針・影響範囲・テスト方針をユーザーに提示し、承認を得る(`~/.claude/CLAUDE.md`の「実装前にプランを提示する」方針に沿う)。承認を得てから実装に進む

## 実装・自己レビュー

1. 承認された実装方針に沿って実装する。既存コードのスタイル・命名規則に合わせ、流用できる既存の関数・ユーティリティがあれば新規実装せずそれを使う
2. 承認された影響範囲を超える変更が必要になった場合は、その旨をユーザーに報告し、方針の見直しを確認する
3. diffを見直し、意図しない変更(デバッグ用の記述の残存、無関係な差分など)や、過剰な抽象化・不要なエラーハンドリングが混入していないか自己レビューする

## テスト以降

自己レビューが終わったら、以下を`dev-workflow-shared`のセクションに沿って実行する。実装方針の確認ステップで把握した「期待動作」がテストの確認対象になる。

1. 「テスト実行」
2. 「`notion-task-workflow`への橋渡し」
3. 「PR下書き作成」
