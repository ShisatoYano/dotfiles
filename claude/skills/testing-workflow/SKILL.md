---
name: testing-workflow
description: Use for test/verification work — either a Notion task whose purpose is verification only (e.g. final real-hardware confirmation, dedicated test-writing) without accompanying implementation or bug-fix work, or as the shared test-execution step invoked by `dev-workflow-shared` on behalf of `implementation-workflow`/`bug-investigation-workflow`. Splits testing into a local flow (unit tests, simulation-based integration — Claude can run these directly) and a real-hardware (実機) flow (Claude prepares the procedure, the user carries it out and reports results back).
---

# Testing Workflow

テストによる検証作業を、ローカル(ユニット/シミュレーション結合)と実機の2つのフローに分けて支援する。`dev-workflow-shared`の「テスト実行」から共通の検証手段として呼び出されるほか、検証のみが目的のNotionタスク(最終実機確認など、実装・不具合修正を伴わないもの)自体を扱う独立したジャンルとしても使う。

## 前提

- テストの進め方は、このdotfilesの`~/.claude/CLAUDE.md`の「テスト」節に従う: まずローカルで検証できる範囲を最大化する、テストケースは必要以上に増やさない
- テストコードのpush・PR作成など状態変更操作は、毎回ユーザーの明示確認を得てから実行する(`~/dotfiles/claude/rules/write-approval.md`参照)
- 実装/不具合修正ワークフローの一部として呼ばれた場合と、独立したNotionタスクとして着手する場合とで、後半の扱いが変わる(「完了後」セクション参照)

## 事前準備

独立したNotionタスクとして着手する場合は、`dev-workflow-shared`の「事前準備: リポジトリの最新化確認」を実行する。実装/不具合修正ワークフローの一部として呼ばれた場合は、呼び出し元ですでに実施済みのためスキップする。

## テスト対象・期待結果の確認

1. 独立したNotionタスクとして着手する場合、Notionタスクページの内容(`タスクのゴール`、`何のため？`などの説明文)から、何を検証すべきか・期待する結果を把握する
2. 実装/不具合修正ワークフローの一部として呼ばれた場合は、呼び出し元がすでに明らかにした期待結果(実装なら期待動作、不具合修正なら再現解消)とテスト方針をそのまま使う
3. 検証範囲(ユニット/シミュレーション結合/実機のどこまで必要か)を確認する。不明であればユーザーに確認する

## ローカルテストフロー(ユニット/シミュレーション結合)

Claudeが自走して実行できる範囲。

1. まず既存のユニットテスト・スタブ/モックを活用してローカルで確認できる範囲を最大化する(`~/.claude/CLAUDE.md`のテスト方針)
2. 既存のテストでカバーしきれない場合のみ追加する。テストケースは必要以上に増やさず、各ケースについてなぜそのケースが必要かを明確にする
3. シミュレーションによる結合テストが必要な場合は、対象のシミュレーション環境で実行する(起動方法は対象プロジェクトのCLAUDE.md/READMEを確認する)
4. シミュレーション終了時は、起動した全プロセスが確実に終了したことをプロセス一覧等で確認してから次に進む。`pkill -f`等のデフォルトシグナル(SIGTERM)は子プロセスに伝播せず孤児化して残り続けることがあり、それが次回以降のローカルテストの誤動作(名前衝突など)につながるため、対象プロジェクトの正規の終了手順を使う
5. 実行結果(pass/fail、ログ、失敗時の原因)をまとめる

## 実機テストフロー

Claudeは実機を直接操作できないため、ユーザーへの依頼という形で進める。

1. 実機での確認に必要な手順(準備するもの、操作手順、確認すべき挙動・出力、安全上の注意点があれば含める)をチェックリストとして整理する
2. 整理した手順をユーザーに提示し、実施を依頼する
3. ユーザーから実施結果(挙動・ログ・数値など)を受け取り、期待結果と照合する
4. 想定外の結果が得られた場合は、その内容を整理してユーザーに報告する。原因調査が必要そうであれば、呼び出し元が`bug-investigation-workflow`ならその場で原因調査に戻ることを、独立したテストタスクなら新規の不具合タスクとして起票することを提案する

## 完了後

1. ローカル/実機それぞれの結果を整理する
2. 実装/不具合修正ワークフローの一部として呼ばれた場合は、整理した結果を呼び出し元に返す(以降の`notion-task-workflow`への橋渡し・PR下書き作成は呼び出し元が行う)
3. 独立したNotionタスクとして着手した場合は、`dev-workflow-shared`の「`notion-task-workflow`への橋渡し」を実行する。テストコードの追加などpushが必要な変更があれば、続けて「PR下書き作成」も実行する
