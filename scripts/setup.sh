#!/usr/bin/env bash
set -eo pipefail

echo "=== 事前準備 (apt update) ==="
sudo apt update

# ---------------------------------------------
# WezTerm
# ---------------------------------------------
echo "=== WezTerm ==="
if ! command -v wezterm &> /dev/null; then
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/wezterm-fury.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
  sudo apt update
  sudo apt install -y wezterm
else
  echo "wezterm はインストール済みです。スキップします。"
fi

echo "=== Nerd Font (JetBrainsMono Nerd Font) ==="
if [ ! -d ~/.local/share/fonts/JetBrainsMonoNerdFont ]; then
  mkdir -p ~/.local/share/fonts/JetBrainsMonoNerdFont
  curl -Lo /tmp/JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  unzip -o /tmp/JetBrainsMono.zip -d ~/.local/share/fonts/JetBrainsMonoNerdFont > /dev/null
  rm /tmp/JetBrainsMono.zip
  fc-cache -f ~/.local/share/fonts > /dev/null
else
  echo "JetBrainsMono Nerd Font はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# Neovim
# ---------------------------------------------
echo "=== Neovim ==="
if ! command -v nvim &> /dev/null; then
  curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
  sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
  sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
  rm nvim-linux-x86_64.tar.gz
else
  echo "nvim はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# Treesitter用: build-essential + tree-sitter CLI
# ---------------------------------------------
echo "=== build-essential ==="
sudo apt install -y build-essential unzip

echo "=== tree-sitter CLI ==="
if ! command -v tree-sitter &> /dev/null; then
  curl -LO https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-cli-linux-x64.zip
  unzip -o tree-sitter-cli-linux-x64.zip
  sudo mv tree-sitter /usr/local/bin/tree-sitter
  sudo chmod +x /usr/local/bin/tree-sitter
  rm tree-sitter-cli-linux-x64.zip
else
  echo "tree-sitter はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# Node.js / npm (pyright, git-cz用)
# ---------------------------------------------
echo "=== Node.js ==="
if ! command -v node &> /dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt install -y nodejs
else
  echo "node はインストール済みです。スキップします。"
fi

# npmのグローバルインストール先をユーザー領域に変更(sudoなしでグローバルインストールできるようにする)
echo "=== npmのグローバルインストール先を設定 ==="
if [ "$(npm config get prefix)" != "$HOME/.npm-global" ]; then
  mkdir -p ~/.npm-global
  npm config set prefix "$HOME/.npm-global"
  if ! grep -q "npm-global" ~/.bashrc; then
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
  fi
  export PATH="$HOME/.npm-global/bin:$PATH"
else
  echo "npmのプレフィックスは設定済みです。スキップします。"
fi

echo "=== git-cz ==="
if ! command -v git-cz &> /dev/null; then
  npm install -g git-cz
else
  echo "git-cz はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# ImageMagick (Neovimでの画像プレビュー、image.nvim用)
# ---------------------------------------------
echo "=== ImageMagick ==="
sudo apt install -y imagemagick

# ---------------------------------------------
# Python (debugpy用)
# ---------------------------------------------
echo "=== python3-venv ==="
sudo apt install -y python3-venv

# ---------------------------------------------
# 検索系: ripgrep, fd-find
# ---------------------------------------------
echo "=== ripgrep / fd-find ==="
sudo apt install -y ripgrep fd-find

# ---------------------------------------------
# gh (GitHub CLI)
# ---------------------------------------------
echo "=== gh ==="
if ! command -v gh &> /dev/null; then
  (type -p wget >/dev/null || (sudo apt update && sudo apt install -y wget)) \
  && sudo mkdir -p -m 755 /etc/apt/keyrings \
  && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && sudo mkdir -p -m 755 /etc/apt/sources.list.d \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt update \
  && sudo apt install -y gh
else
  echo "gh はインストール済みです。スキップします。"
fi


# ---------------------------------------------
# fzf(公式インストーラー、apt版は機能が古いため使わない)
# ---------------------------------------------
echo "=== fzf ==="
if [ ! -d ~/.fzf ]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install --all
else
  echo "fzf はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# pipx / buku(CLIブックマーク管理、fzf連携はshell/aliases.shのbb関数)
# ---------------------------------------------
echo "=== pipx ==="
if ! command -v pipx &> /dev/null; then
  sudo apt install -y pipx
else
  echo "pipx はインストール済みです。スキップします。"
fi

echo "=== buku ==="
if ! command -v buku &> /dev/null; then
  pipx install buku
else
  echo "buku はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# starship(プロンプト、公式インストーラーでユーザー領域にインストール)
# ---------------------------------------------
echo "=== starship ==="
if ! command -v starship &> /dev/null; then
  mkdir -p ~/.local/bin
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin
else
  echo "starship はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# Go(ccsession等のGo製CLIツールのビルド用)
# ---------------------------------------------
echo "=== Go ==="
if ! command -v go &> /dev/null; then
  sudo apt install -y golang-go
else
  echo "go はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# Claude Code
# ---------------------------------------------
echo "=== Claude Code ==="
if ! command -v claude &> /dev/null; then
  npm install -g @anthropic-ai/claude-code
else
  echo "claude はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# ccsession(Claude Codeセッション検索)
# ---------------------------------------------
echo "=== ccsession ==="
if ! command -v ccsession &> /dev/null; then
  go install github.com/sorafujitani/ccsession/cmd/ccsession@latest
else
  echo "ccsession はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# ghq
# ---------------------------------------------
echo "=== ghq ==="
if ! command -v ghq &> /dev/null; then
  curl -LO https://github.com/x-motemen/ghq/releases/latest/download/ghq_linux_amd64.zip
  unzip -o ghq_linux_amd64.zip
  sudo mv ghq_linux_amd64/ghq /usr/local/bin/ghq
  sudo chmod +x /usr/local/bin/ghq
  rm -rf ghq_linux_amd64.zip ghq_linux_amd64
  git config --global ghq.root '~/ghq'
else
  echo "ghq はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# tabctl(ブラウザタブをCLI操作、fzf連携はshell/aliases.shのta/tc/tabarchive関数)
# ---------------------------------------------
echo "=== tabctl ==="
if ! command -v tabctl &> /dev/null; then
  ghq get https://github.com/slastra/tabctl
  TABCTL_DIR="$(ghq root)/github.com/slastra/tabctl"
  (cd "$TABCTL_DIR" && go build -o tabctl ./cmd/tabctl && go build -o tabctl-mediator ./cmd/tabctl-mediator)
  mkdir -p ~/.local/bin
  cp "$TABCTL_DIR/tabctl" "$TABCTL_DIR/tabctl-mediator" ~/.local/bin/
  tabctl install
  echo "ブラウザ拡張のインストールとブラウザの再起動が必要です:"
  echo "  Chrome系: https://chromewebstore.google.com/detail/tabctl/baomblllgemcgbignhpbipgiofmjdhpn"
  echo "  Firefox系: https://addons.mozilla.org/en-US/firefox/addon/tabctl1/"
else
  echo "tabctl はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# lazygit
# ---------------------------------------------
echo "=== lazygit ==="
if ! command -v lazygit &> /dev/null; then
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
  curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  tar xf lazygit.tar.gz lazygit
  sudo install lazygit /usr/local/bin
  rm lazygit.tar.gz lazygit
else
  echo "lazygit はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# delta(git diffを見やすくするページャー)
# ---------------------------------------------
echo "=== git-delta ==="
if ! command -v delta &> /dev/null; then
  sudo apt install -y git-delta
else
  echo "delta はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# gibo(.gitignoreテンプレート生成CLI)
# ---------------------------------------------
echo "=== gibo ==="
if ! command -v gibo &> /dev/null; then
  curl -Lo gibo.tar.gz "https://github.com/simonwhitaker/gibo/releases/latest/download/gibo_Linux_x86_64.tar.gz"
  tar xf gibo.tar.gz gibo
  sudo install gibo /usr/local/bin
  rm gibo.tar.gz gibo
else
  echo "gibo はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# クリップボード連携
# ---------------------------------------------
echo "=== クリップボード連携ツール ==="
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
  sudo apt install -y wl-clipboard
elif [ "$XDG_SESSION_TYPE" = "x11" ]; then
  sudo apt install -y xclip
else
  echo "セッションタイプを自動検出できませんでした。手動でクリップボードツール(wl-clipboardまたはxclip)を入れてください。"
fi

# ---------------------------------------------
# dotfilesのシンボリックリンク
# ---------------------------------------------
echo "=== dotfilesのリンク設定 ==="
mkdir -p ~/.config
if [ ! -e ~/.config/wezterm ]; then
  ln -s ~/dotfiles/wezterm ~/.config/wezterm
  echo "wezterm設定をリンクしました"
fi
if [ ! -e ~/.config/nvim ]; then
  ln -s ~/dotfiles/nvim ~/.config/nvim
  echo "nvim設定をリンクしました"
fi
mkdir -p ~/.config/lazygit
if [ ! -e ~/.config/lazygit/config.yml ]; then
  ln -s ~/dotfiles/lazygit/config.yml ~/.config/lazygit/config.yml
  echo "lazygit設定をリンクしました"
fi
if [ ! -e ~/.config/starship.toml ]; then
  ln -s ~/dotfiles/starship/starship.toml ~/.config/starship.toml
  echo "starship設定をリンクしました"
fi

echo "=== シェルエイリアス(gcd等)の読み込み設定 ==="
if ! grep -q "dotfiles/shell/aliases.sh" ~/.bashrc; then
  echo 'source ~/dotfiles/shell/aliases.sh' >> ~/.bashrc
  echo "shell/aliases.shの読み込みを~/.bashrcに追記しました"
else
  echo "shell/aliases.shは読み込み設定済みです。スキップします。"
fi

echo "=== starshipプロンプトの初期化設定 ==="
if ! grep -q "starship init bash" ~/.bashrc; then
  echo 'eval "$(starship init bash)"' >> ~/.bashrc
  echo "starship initを~/.bashrcに追記しました"
else
  echo "starship initは設定済みです。スキップします。"
fi

echo "=== セットアップ完了 ==="
echo "ターミナルを再起動するか、'nvim' と 'wezterm' を起動して動作確認してください。"
