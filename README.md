# My dotfiles

WezTerm / Neovim / Git を中心に、ターミナル作業環境全体(ブックマーク管理・ブラウザタブ操作・プロンプトなど)をまとめて管理するリポジトリ

## 環境構築

```bash
git clone git@github.com:あなたのユーザー名/dotfiles.git ~/dotfiles
~/dotfiles/scripts/setup.sh
```

上記スクリプトで以下がまとめてインストール・リンク・有効化されます。

- WezTerm、Neovim(最新版)
- tree-sitter CLI、Node.js / npm(LSP, git-cz用)
- ripgrep, fd-find, fzf
- gh(gh-dash拡張含む), ghq, git-cz, lazygit, git-delta, gibo
- Go(ccsession等のビルド用)、ccsession
- Docker(公式apt repo経由)、`docker`グループへの追加
- starship(プロンプト)
- jq、Claude Codeのstatusline(モデル名/コンテキスト使用率/利用制限%を表示)
- Claude Codeのskills(`claude/skills/` を `~/.claude/skills` にリンク。日々の定型作業をSkill化して蓄積していく)
- Claude CodeのCLAUDE.md(`claude/CLAUDE.md` を `~/.claude/CLAUDE.md` にリンク。全プロジェクト共通の指示)
- pipx, buku(CLIブックマーク管理)、tabctl(ブラウザタブ操作)
- Slidev(Markdownで書く発表資料。`~/slides`にワークスペースを用意し、PDF/PPTX/PNG書き出し用のChromiumまで入れる)
- ログイン時の自動起動(WezTerm、Chrome、xhost-docker)
- `~/.config/wezterm`, `~/.config/nvim` 等へのシンボリックリンク

### 構築手順の実体はAnsible

`scripts/setup.sh` はansibleを用意してplaybookを流すだけのブートストラップで、
実際の手順は `ansible/` 以下にあります。何を入れるか(パッケージ名・ダウンロードURL・
リンクの対応表)は `ansible/group_vars/all.yml` に集約してあるので、
**ツールの追加・削除は基本このファイルだけを編集**すれば済みます。

`setup.sh` に渡した引数はそのまま `ansible-playbook` に渡ります。

```bash
~/dotfiles/scripts/setup.sh --check       # 何が変わるかだけ見る(dry-run)
~/dotfiles/scripts/setup.sh --tags bins   # リリースバイナリの配置だけやり直す
~/dotfiles/scripts/setup.sh --list-tasks  # 実行される手順の一覧
```

使えるタグは `apt` / `repos` / `packages` / `bins` / `lang` / `links` です。
再実行は安全で、既に入っているものはスキップされます。

`--check` は構築済みのマシンで差分を見る用途向けです。以下は仕様上の制約なので、
出ても異常ではありません。

- 署名鍵の取得が `changed` と出ることがある。`get_url` はmtimeベースの条件付きGETで
  判定し、dry-runでは中身を比較できないため。本実行では内容を比較するので `ok` になる
- tar.gz で配布されるツール(nvim/lazygit/gibo/mdroll)の展開は表示されない。
  `unarchive` が tar をcheckモードで扱えずスキップするため。本実行では正常に入る
- まっさらなマシンでは途中で止まる。リポジトリ登録が実際には行われないので、
  直後の `apt install` がパッケージを見つけられない。素のマシンではそのまま本実行する

## 主なシェル関数(`shell/aliases.sh`)

| コマンド | 動作 |
|---|---|
| `gcd` | ghq管理下のリポジトリをあいまい検索して移動 |
| `bb` | bukuのブックマークをあいまい検索してブラウザで開く |
| `tabarchive` / `tabarchive-all` | タブをbukuに保存してから閉じる |
| `tabnote` | タブをbukuに保存し、ページ内容をClaudeで要約したメモをnbの`tab-archive`に残してから閉じる |
| `workstart` | 毎日の業務開始時に開くページ(bukuの`*_check`タグ=Notion/勤怠/Slack等)をまとめて開く |
| `ff` | 指定ディレクトリ以下のファイルをあいまい検索 |
| `dc` / `dexec` / `dstop` | docker composeの短縮形、コンテナ選択して入る/停止 |
| `prs` | 自分に関するPRを横断で確認 |
| `slidenew` / `slidedev` / `slideexport` | Slidevの発表資料を作成・プレビュー・書き出し |

詳しい使い方や、その他のキーバインドは `docs/terminal-cheatsheet.md` を参照。
Git操作は `docs/git-cheatsheet.md`、Neovimの標準操作は `docs/nvim-cheatsheet.md` にまとめている
(Neovim内から `<leader>wh` / `<leader>gh` / `<leader>nh` でそれぞれ開ける)。
発表資料(Slidev)の記法とコマンドは `docs/slidev-cheatsheet.md`(`<leader>sh`)にまとめている。

## 補足

- Neovimのプラグイン本体は初回起動時に `lazy.nvim` が自動インストールします
- LSPサーバー(clangd, pyright, lua_ls)とデバッガ(codelldb, debugpy)は初回起動時に `mason.nvim` が自動インストールします
- 発表資料は `~/slides/decks/<日付>-<タイトル>/slides.md` に置く。`~/slides` の `package.json` と
  `node_modules` は `slidev/` へのリンクなので、**依存の追加は `~/dotfiles/slidev` で `npm install <パッケージ>`** する
  (`~/slides` 側で実行するとリンクが実ファイルに置き換わる)
- ROS 2ワークスペースでC++の補完を効かせるには `colcon build --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` でビルドしてください
- ROS 2ワークスペースでPythonの自作パッケージ補完を効かせるには、ワークスペース直下で
  `python3 ~/dotfiles/scripts/generate_pyright_paths.py` を実行してください
  (`install/`以下のsite-packagesパスを集めて`pyrightconfig.json`を生成します)
