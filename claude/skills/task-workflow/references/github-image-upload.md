# GitHubへの画像のアップロード

`gh`にもGitHubの公開APIにも、本文にドラッグ&ドロップするのと同じ画像のアップロード機能が無いため、Claude in Chromeでブラウザの編集欄を経由してURL(`https://github.com/user-attachments/assets/...`)を得る。得たURLは`gh pr create --body`や`gh pr edit --body`の本文に入れる。

## 手順

1. `claude-in-chrome`スキルを読み込み、新しいタブで対象リポジトリの`https://github.com/<owner>/<repo>/issues/new`を開く(作成前のPRにも貼れるよう、どのリポジトリにもある編集欄を使う。Issueは作らない。Issuesが無効なら、作成済みのPRのコメント欄を使う)
2. 編集欄のファイル入力はクリックした瞬間に作られ、そのままではネイティブのファイル選択画面が開いて操作できなくなる。`javascript_tool`で`HTMLInputElement.prototype.click`を差し替え、`type=file`ならダイアログを開かずに`document.body`へ追加するようにしてから、「Paste, drop, or click to add files」のボタンをJavaScriptでクリックする
3. `find`で追加されたファイル入力の`ref`を探し、`file_upload`で画像を渡す(1回の合計は10MBまで)
4. 数秒待ってから`textarea`の値を読み、`<img ... src="https://github.com/user-attachments/assets/...">`を取り出す
5. `textarea`を空にしてから(ネイティブのsetterで値を消し`input`イベントを送る。内容が残ったまま閉じると離脱確認のダイアログが出て操作できなくなる)、タブを閉じる

## 失敗したとき

ボタンやファイル入力が見つからない、アップロード後に`textarea`へURLが入らない、など2回試してうまくいかなければ打ち切る。ユーザーに画像のパスと貼る見出しを示し、手で貼ってもらう。
