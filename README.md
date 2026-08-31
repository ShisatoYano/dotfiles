# My dotfiles

WezTerm / Neovim / Git を中心に、ターミナル作業環境全体(ブックマーク管理・プロンプトなど)をまとめて管理するリポジトリ

## 環境構築

```bash
git clone git@github.com:あなたのユーザー名/dotfiles.git ~/dotfiles
~/dotfiles/scripts/setup.sh
```

上記スクリプトで以下がまとめてインストール・リンク・有効化されます。

- WezTerm、Neovim(最新版)
- tree-sitter CLI、Node.js / npm(LSP, git-cz用)
- ripgrep, fd-find, fzf
- gh, ghq, git-cz, lazygit, git-delta, gibo
- Go(ccsession等のビルド用)、ccsession
- Docker(公式apt repo経由)、`docker`グループへの追加
- starship(プロンプト)
- jq、Claude Codeのstatusline(モデル名/コンテキスト使用率/利用制限%を表示)
- Claude Codeのskills(`claude/skills/` を `~/.claude/skills` にリンク。日々の定型作業をSkill化して蓄積していく)
- Claude CodeのCLAUDE.md(`claude/CLAUDE.md` を `~/.claude/CLAUDE.md` にリンク。全プロジェクト共通の指示)
- pipx, buku(CLIブックマーク管理)
- ログイン時の自動起動(WezTerm、Chrome、xhost-docker)
- `~/.config/wezterm`, `~/.config/nvim` 等へのシンボリックリンク

## 主なシェル関数(`shell/aliases.sh`)

| コマンド | 動作 |
|---|---|
| `gcd` | ghq管理下のリポジトリをあいまい検索して移動 |
| `bb` | bukuのブックマークをあいまい検索してブラウザで開く |
| `ff` | 指定ディレクトリ以下のファイルをあいまい検索 |
| `dc` / `dexec` / `dstop` | docker composeの短縮形、コンテナ選択して入る/停止 |
| `prs` | 自分に関するPRを横断で確認 |

詳しい使い方や、その他のキーバインドは `docs/terminal-cheatsheet.md` を参照。
Git操作は `docs/git-cheatsheet.md`、Neovimの標準操作は `docs/nvim-cheatsheet.md` にまとめている
(Neovim内から `<leader>wh` / `<leader>gh` / `<leader>nh` でそれぞれ開ける)。

## 補足

- Neovimのプラグイン本体は初回起動時に `lazy.nvim` が自動インストールします
- LSPサーバー(clangd, pyright, lua_ls)とデバッガ(codelldb, debugpy)は初回起動時に `mason.nvim` が自動インストールします
- ROS 2ワークスペースでC++の補完を効かせるには `colcon build --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` でビルドしてください
- ROS 2ワークスペースでPythonの自作パッケージ補完を効かせるには、ワークスペース直下で
  `python3 ~/dotfiles/scripts/generate_pyright_paths.py` を実行してください
  (`install/`以下のsite-packagesパスを集めて`pyrightconfig.json`を生成します)
