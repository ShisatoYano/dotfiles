# My dotfiles

WezTerm / Neovim / Git関連の設定を管理するリポジトリ

## 環境構築

```bash
git clone git@github.com:あなたのユーザー名/dotfiles.git ~/dotfiles
~/dotfiles/scripts/setup.sh
```

上記スクリプトで以下がまとめてインストール・リンクされます。

- WezTerm
- Neovim（最新版）
- tree-sitter CLI（Neovimのシンタックスハイライト用）
- Node.js / npm（LSP, git-cz用）
- ripgrep, fd-find（Neovimのファイル検索用）
- gh, ghq, git-cz, lazygit, git-delta, gibo
- `~/.config/wezterm`, `~/.config/nvim` へのシンボリックリンク

## 補足

- Neovimのプラグイン本体は初回起動時に `lazy.nvim` が自動インストールします
- LSPサーバー（clangd, pyright, lua_ls）とデバッガ（codelldb, debugpy）は初回起動時に `mason.nvim` が自動インストールします
- ROS 2ワークスペースでC++の補完を効かせるには `colcon build --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` でビルドしてください
- Pythonの自作パッケージ補完には `python3 ~/dotfiles/scripts/generate_pyright_paths.py` （エイリアス: `gen-pyright`）の実行が必要です
