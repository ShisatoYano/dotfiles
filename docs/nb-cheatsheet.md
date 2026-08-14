# nb(メモ管理) チートシート

## notebook
| コマンド | 動作 |
|---|---|
| `nb notebooks` | notebook一覧 |
| `nb notebooks add <name>` | notebook作成 |
| `nb notebooks current` | 現在のnotebookを表示 |
| `nb use <name>`(短縮: `nb u <name>`) | notebookを切り替え(永続化される) |

## CLI基本
| コマンド | 動作 |
|---|---|
| `nb add` | エディタ(nvim)を開いてノート作成 |
| `nb add --filename "<name>.md" --content "<text>"` | 内容を渡してその場でノート作成 |
| `nb ls` | 一覧表示(トップレベルのみ、フォルダは1エントリにまとまる) |
| `nb show <id>` | 内容を表示(lessページャ) |
| `nb show <id> --print --no-color` | 内容をそのまま標準出力 |
| `nb show <id> --path` | 絶対パスを表示 |
| `nb edit <id>` | エディタ(nvim)で編集 |
| `nb delete <id>` | 削除(確認あり) |

フォルダ配下のノートを直接指定したいときは、`nb ls`や`nb search --path`で得た絶対パスを
そのまま`<id>`の代わりに渡せる(例: `nb edit "/home/yano/.nb/work/foo/foo.md"`)。

## タグ
タグは専用コマンドではなく、本文中に`#タグ名`と書くだけ。
| コマンド | 動作 |
|---|---|
| `nb add ... --tags tag1,tag2` | 作成時にタグを付与 |
| `nb search --tag <name>` | タグで絞り込み検索 |
| `nb search --tags` | notebook内の全タグ一覧 |

`nb ls --tags`(引数なし)は絞り込みではなく「全タグ一覧」なので注意。

## 検索
| コマンド | 動作 |
|---|---|
| `nb search <query>`(短縮: `nb q <query>`) | 全文検索(git grepベース、フォルダ配下も対象) |
| `nb search <query> --path` | マッチしたファイルの絶対パスのみ出力 |

## シェル関数(`shell/aliases.sh`、要fzf)
| コマンド | 動作 |
|---|---|
| `nba <url>` | URL(HTML/PDF)を渡すとタイトル自動取得してメモ作成。`<タイトル>/<タイトル>.md`というフォルダ構成 |
| `nba "<title>" <url>` | タイトルを手動指定 |
| `nbsum <id>` | ノート内のURLをClaudeに要約させ、本文末尾に「## 要約」+「## 詳細」を追記。PDFなら埋め込み図も抽出して同じフォルダに保存 |
| `nbq <query>` | 全文検索してfzfでプレビューしながら選択 → nvimで編集 |
| `nbmd` | ノートをfzfで選んで`mdroll --watch`でプレビュー |

## Neovim(`nvim/lua/plugins/nb.lua`)
| キー | 動作 |
|---|---|
| `<leader>na` | ノート作成(現在のnotebookに追加、notebook外なら選択にフォールバック) |
| `<leader>nA` | notebookを選んでノート作成 |
| `<leader>np` | 全notebook横断でノートをあいまい検索 |
| `<leader>ng` | ノート内容をlive grep |
| `<leader>ni` | 画像インポート(クリップボード優先、無ければファイルパス入力) |
| `<leader>nl` | ノート/画像へのリンク挿入(`[[note]]` / `[[notebook:note]]`) |
| `<leader>nm` | 現在のノートを別notebookへ移動 |
| `<leader>nM` | 外部ファイルを現在のnotebookに取り込む |

`autosync = true`にしているため、ノートを保存して閉じると自動でgit commitされる
(リモート未設定なのでpushは行われない)。

## git管理(リモート無し、ローカルgitのみ)
| コマンド | 動作 |
|---|---|
| `nb git <git-options>...` | cd不要でcurrent notebookに対してgitコマンド実行(例: `nb git log`、`nb git diff`) |
| `nb git checkpoint "<message>"` | 未コミット分を手動コミット |
| `lazygit -p ~/.nb/<notebook>` | 該当notebookのgit管理をTUIで操作(push/pull以外は通常通り使える) |

## タブ補完
新しいターミナルを開けば`nb <Tab>`でサブコマンド・オプション補完が効く
(`~/.local/share/bash-completion/completions/nb`にsudoなしでインストール済み)。
