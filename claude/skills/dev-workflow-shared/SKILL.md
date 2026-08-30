---
name: dev-workflow-shared
description: Shared steps used by genre-specific development workflow Skills (`bug-investigation-workflow`, `implementation-workflow`, and any future dev-genre Skill) before and after their genre-specific investigation/design step — repo-freshness pre-check, previous-progress check (Notion page history and daily-task-logs carryover), tiered test execution, handoff to `notion-task-workflow`, and PR draft prep. Invoked by those Skills as sub-steps; not typically triggered directly by the user.
---

# Dev Workflow Shared

ソフトウェア開発系のジャンル別Skill(`bug-investigation-workflow`、`implementation-workflow`など)が共通して使う工程をまとめたもの。呼び出し元のSkillが、原因調査・要件確認などジャンル固有のステップを終えたあとに、ここのセクションを呼び出す。

## 前提

- 修正・実装のpush・PR作成など状態変更操作は、毎回ユーザーの明示確認を得てから実行する(`~/dotfiles/claude/rules/write-approval.md`参照)
- Notionタスクページへの進捗記録・タスク完了は`notion-task-workflow` Skillに委譲する(ここでは重複させない)
- 対象リポジトリ以外の場所で作業しているときに`git`コマンドを対象リポジトリへ向ける場合は、`cd <path> && git ...`ではなく`git -C <path> ...`を使う。`cd`を挟むとリポジトリのhookが実行されうるとしてツール側の確認が挟まるため

## 事前準備: リポジトリの最新化確認

作業に入る前に行う。

1. 作業対象に関連するローカルの各リポジトリ(サブモジュールを含む)について、本流ブランチ名を`develop`と決め打ちせず、`git symbolic-ref refs/remotes/origin/HEAD --short`(または`git remote show origin`)で確認する。その上で`git fetch`し、ローカルの本流ブランチが`origin/<本流ブランチ>`から遅れていないか確認する
2. 遅れているリポジトリがあれば一覧にしてユーザーに提示し、先に最新化(pull等)するよう促す。更新作業自体は自動実行せず、ユーザーに依頼する
3. 全て最新であることを確認できてから、呼び出し元のジャンル固有のステップ(原因調査・要件確認など)に進む

## 事前準備: 前回までの進捗確認

Notionタスク対象の場合、リポジトリの最新化確認と合わせて、ジャンル固有のステップに進む前に行う。持ち越しタスク(前回セッションで完了しなかったもの)を、初見のタスクとして扱って重複調査・手戻りを起こさないようにするため。

1. 対象のNotionタスクページ全体を確認し、`notion-task-workflow`のサブワークフロー1(進捗記録)で過去に追記された内容が無いか確認する。あれば、前回までの調査・実装状況(何を確認済みか、次にやろうとしていたこと)を踏まえた上でジャンル固有のステップに進む
2. `daily-task-logs`の直近の`daily/*.md`(`notion-task-planning`が持ち越し把握に読むのと同じ)も確認し、当該タスクについてのコンテキスト区切り時の途中経過メモがあれば参照する

## テスト実行

`testing-workflow`の「テスト対象・期待結果の確認」(呼び出し元のSkillで承認済みのテスト方針・期待結果をそのまま渡す)、「ローカルテストフロー」、「実機テストフロー」を実行する。結果は呼び出し元のSkillに返し、次の「`notion-task-workflow`への橋渡し」に進む。

## `notion-task-workflow`への橋渡し

呼び出し元のSkill自身はNotionページへの書き込みを行わない。ここまでの内容を整理し、`notion-task-workflow`のサブワークフローに委譲する。

1. 作業が難航し、その日中の完了が見込めないと判断した場合は、無理に完了を目指さず区切りの良いところで作業を区切る。その時点までの進捗を整理し、`notion-task-workflow`のサブワークフロー1(進捗記録)で記録した上で、今後の進め方(今日中に続けるか、翌日以降に持ち越すか)をユーザーに確認する
2. 完了した場合は、作業内容・テスト結果を整理する
3. `notion-task-workflow`のサブワークフロー1(進捗記録)を呼び出し、2で整理した内容を進捗として記録する
4. 作業が完了し次第、`notion-task-workflow`のサブワークフロー2(タスク完了)を呼び出し、最終まとめの記録とステータス更新を行う

## PR下書き作成

1. 作業用ブランチを作成する(まだ作っていない場合)。ブランチ名は既存の命名規則に合わせる
2. 変更をコミットする。コミットメッセージは既存のコミットログのスタイルに合わせる
3. 対象リポジトリにPRテンプレート(`.github/PULL_REQUEST_TEMPLATE.md`など)が用意されていないか確認する。あればそのテンプレートに従って、無ければ既存のPRのスタイルを参考にPRのタイトル・本文を下書きする。本文には作業内容・テスト結果(ユニット/シミュレーション/実機)を含め、対象のNotionタスクへのリンクも記載する
4. push・PR作成(`gh pr create`)は、下書き内容を提示し承認を得てから実行する(前提の承認ゲート参照)。PRの作成者は`gh`のローカル認証に紐づくためユーザー自身のアカウントになり、Claudeの関与はコミットの`Co-Authored-By`トレイラーで表現する
