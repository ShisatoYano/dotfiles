# 書き込み系アクション承認ゲート

外部に影響する書き込み系アクション(実装方針の確定、Notionページへの書き込み、push・PR作成、PRへのレビュー送信・返信)は、内容を先にユーザーへ提示し、明示的な承認を得てから実行する。

- **MUST**: 実行前に対象内容(実装方針・影響範囲・テスト方針、Notion追記内容、PR下書き、レビュー・返信の本文など)をそのまま提示する。要約や省略をしない
- **MUST**: ユーザーの明示的な承認を得るまで実行しない。コンテキスト圧縮直前の自動サマリ等、急ぐ状況でもこの手順を省略しない
- **MUST NOT**: 承認された範囲を超える変更が必要になった場合、無断で拡大せず、その旨を報告して方針の見直しを確認する

## hookとの役割分担

- PreToolUse hookで機械的に制御される(`~/dotfiles/claude/hooks/`)。これは「承認前にコマンド自体が実行されない」という最終防波堤
  - ブロック(PR操作、`block-pr-write-actions.py`): `gh pr review/comment`、`--match-head-commit <sha>`の無い`gh pr merge`、`gh api`でのリポジトリの`pulls`・`issues`以下への書き込み全般(GET以外すべて。`-f`/`-F`/`--input`による暗黙のPOSTを含み、Issueの起票・編集も止まる。後述のレビュー送信・返信のPOSTを除く)、`mutation`を含むかクエリをファイル・変数から読む`gh api graphql`、`gh alias set/import`、許可されたPOSTを他のコマンドとつないだ形。`gh`の引数に引用符の外の変数展開・コマンド置換があるもの(`gh pr view $N`のような読み取りも含む)もブロックされるので、変数は`"$N"`のように二重引用符で囲む。コミットメッセージや本文に文字列として含むだけでもブロックされるので、その場合は本文をWriteツールでファイルに書いて渡す(`git commit -F <file>`など)
  - ブロック(push、`block-git-push.py`): default branchへのpush(dotfilesを除く)・force push・リモートブランチ削除・全ブランチをまとめたpush(`--all`/`--mirror`など)・宛先を決められないpush(refspec無しか`HEAD`指定で、HEADがdetached)。同じコマンド内に`cd`(`pushd`/`popd`)があるとリポジトリと現在のブランチを特定できず、refspec無し・`HEAD`指定・default branch宛て(dotfilesでも)のpushがブロックになるので、pushは`cd`とつながず`git -C <path> push`で実行する
  - ブロック(変更の破棄、`block-discard-changes.py`): 作業ツリーの変更を破棄するgitコマンド(`git checkout -- <path>`、`git restore`、`git reset --hard`、`git stash`、`git clean -f`)
  - 実行ごとに承認プロンプト: 上記以外の`git push`(dotfilesのdefault branchへのpushを含む)、`--match-head-commit <sha>`付きの`gh pr merge`(最後に指定したshaが、変数を使わない16進の値のとき)、ブランチの作成・切替(`git checkout`/`switch`、`gh pr checkout`。`ask-branch-checkout.py`)、worktreeの作成(`git worktree add`・EnterWorktree。`ask-worktree-creation.py`)
- PRへのレビュー送信・返信(reviews / replies / issues commentsへのPOST)は、`pr-workflow`が使うためhookで許可されており承認プロンプトも出ない。承認は`pr-workflow`の「下書きと送信」の手順で守る
- 承認プロンプトはhookが出すものであり、会話上の承認の代わりにはならない。push等は内容を提示して承認を得たうえで実行する
- 実装方針の承認やNotion書き込みの承認は、「実際にユーザーに提示したか」をhookでは検証できない性質のため、hook化せずSkillの手順として守る
