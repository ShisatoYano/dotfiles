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
# Lua lint/format(Neovimプラグイン開発用): luacheck, stylua
# ---------------------------------------------
echo "=== luacheck ==="
if ! command -v luacheck &> /dev/null; then
  sudo apt install -y lua-check
else
  echo "luacheck はインストール済みです。スキップします。"
fi

echo "=== stylua ==="
if ! command -v stylua &> /dev/null; then
  curl -LO https://github.com/JohnnyMorganz/StyLua/releases/latest/download/stylua-linux-x86_64.zip
  unzip -o stylua-linux-x86_64.zip
  sudo install stylua /usr/local/bin
  rm stylua-linux-x86_64.zip stylua
else
  echo "stylua はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# Node.js / npm (nvm経由)
# ---------------------------------------------
echo "=== nvm / Node.js ==="
if [ ! -d "$HOME/.nvm" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
if ! grep -q "NVM_DIR" ~/.bashrc; then
  cat >> ~/.bashrc << 'EOF'

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
  echo "nvm の読み込み設定を .bashrc に追加しました。"
else
  echo "nvm はインストール済みです。スキップします。"
fi
if ! command -v node &> /dev/null; then
  nvm install --lts
  nvm use --lts
else
  echo "node はインストール済みです。スキップします。"
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
# nb(メモ管理CLI、fzf連携はshell/aliases.shのnba/nbq関数、Neovim連携はnvim/lua/plugins/nb.lua)
# ---------------------------------------------
echo "=== nb ==="
if ! command -v nb &> /dev/null; then
  mkdir -p ~/.local/bin
  curl -Lo ~/.local/bin/nb "https://raw.githubusercontent.com/xwmx/nb/master/nb"
  chmod +x ~/.local/bin/nb
else
  echo "nb はインストール済みです。スキップします。"
fi

# nbのbashタブ補完(bash-completionのユーザーディレクトリに置くのでsudo不要)
if [ ! -f ~/.local/share/bash-completion/completions/nb ]; then
  mkdir -p ~/.local/share/bash-completion/completions
  curl -Lo ~/.local/share/bash-completion/completions/nb \
    "https://raw.githubusercontent.com/xwmx/nb/master/etc/nb-completion.bash"
  echo "nbのタブ補完をインストールしました"
else
  echo "nbのタブ補完はインストール済みです。スキップします。"
fi

# poppler-utils(pdftotext/pdfinfo、shell/aliases.shのnba/nbsumでPDF論文の要約に使用)
echo "=== poppler-utils ==="
if ! command -v pdftotext &> /dev/null; then
  sudo apt install -y poppler-utils
else
  echo "poppler-utils はインストール済みです。スキップします。"
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
# Herdr(複数AIコーディングエージェントの状態を一括で見える化するターミナル多重化ツール、公式インストーラーでユーザー領域にインストール)
# ---------------------------------------------
echo "=== Herdr ==="
if ! command -v herdr &> /dev/null; then
  curl -fsSL https://herdr.dev/install.sh | sh
else
  echo "herdr はインストール済みです。スキップします。"
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
# mdroll(WezTerm向けTUI Markdownビューア)
# ---------------------------------------------
echo "=== mdroll ==="
if ! command -v mdroll &> /dev/null; then
  MDROLL_VERSION=$(curl -s "https://api.github.com/repos/tokuhirom/mdroll/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
  curl -Lo mdroll.tar.gz "https://github.com/tokuhirom/mdroll/releases/latest/download/mdroll-v${MDROLL_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
  tar xf mdroll.tar.gz mdroll
  sudo install mdroll /usr/local/bin
  rm mdroll.tar.gz mdroll
else
  echo "mdroll はインストール済みです。スキップします。"
fi

# ---------------------------------------------
# クリップボード連携
# ---------------------------------------------
# ---------------------------------------------
# Docker(devcontainer等のコンテナ開発用)
# ---------------------------------------------
echo "=== Docker ==="
if ! command -v docker &> /dev/null; then
  sudo apt install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "docker はインストール済みです。スキップします。"
fi

# sudoなしでdockerコマンドを使えるようにする(反映にはログアウト/インし直す必要がある)
if ! groups | grep -q docker; then
  sudo usermod -aG docker "$USER"
  echo "dockerグループに追加しました。反映にはログアウト/インし直してください。"
else
  echo "既にdockerグループに所属しています。スキップします。"
fi

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
mkdir -p ~/.config/herdr
if [ ! -e ~/.config/herdr/config.toml ]; then
  ln -s ~/dotfiles/herdr/config.toml ~/.config/herdr/config.toml
  echo "herdr設定をリンクしました"
fi
if [ ! -e ~/.config/starship.toml ]; then
  ln -s ~/dotfiles/starship/starship.toml ~/.config/starship.toml
  echo "starship設定をリンクしました"
fi
if [ ! -e ~/.gitconfig ]; then
  ln -s ~/dotfiles/git/gitconfig ~/.gitconfig
  echo "git設定(delta等)をリンクしました"
fi

echo "=== Claude Codeのstatusline(モデル名/コンテキスト使用率/利用制限%) ==="
sudo apt install -y jq
mkdir -p ~/.claude
if [ ! -e ~/.claude/statusline-command.sh ]; then
  ln -s ~/dotfiles/claude/statusline-command.sh ~/.claude/statusline-command.sh
  echo "statusline用スクリプトをリンクしました"
fi

# permissions/hooks/statusLineはclaude/settings.jsonにまとめて宣言し、symlinkで配置する。
# theme/enabledPluginsなど機械固有の可変設定は~/.claude/settings.local.json(symlinkしない、
# ユーザースコープのローカルオーバーライド)に置き、dotfiles管理下からは意図的に外す
echo "=== Claude Codeのsettings.json(permissions/hooks/statusLine) ==="
if [ ! -e ~/.claude/settings.json ]; then
  ln -s ~/dotfiles/claude/settings.json ~/.claude/settings.json
  echo "settings.jsonをリンクしました"
elif [ ! -L ~/.claude/settings.json ]; then
  echo "警告: ~/.claude/settings.jsonが既に実ファイルとして存在します。theme/enabledPluginsなど機械固有の設定は~/.claude/settings.local.jsonへ、それ以外はclaude/settings.jsonへ移してから手動でリンクし直してください。" >&2
fi

echo "=== Claude Codeのskills ==="
if [ ! -e ~/.claude/skills ]; then
  ln -s ~/dotfiles/claude/skills ~/.claude/skills
  echo "skillsディレクトリをリンクしました"
fi

echo "=== Claude Codeのagents ==="
if [ ! -e ~/.claude/agents ]; then
  ln -s ~/dotfiles/claude/agents ~/.claude/agents
  echo "agentsディレクトリをリンクしました"
fi

echo "=== HerdrのClaude Code連携(複数エージェントの状態検知hook) ==="
if command -v herdr &> /dev/null && [ ! -f ~/.claude/hooks/herdr-agent-state.sh ]; then
  herdr integration install claude
else
  echo "Herdrのclaude連携hookはインストール済みか、herdr未インストールのためスキップします。"
fi

echo "=== Claude CodeのCLAUDE.md(全プロジェクト共通の指示) ==="
if [ ! -e ~/.claude/CLAUDE.md ]; then
  ln -s ~/dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md
  echo "CLAUDE.mdをリンクしました"
fi

echo "=== tab-check(bukuのURLを決まったタイミングでタブで開く/アクティブにする) ==="
mkdir -p ~/.config/systemd/user
for unit in notion-check attendance-check schedule-check; do
  if [ ! -e ~/.config/systemd/user/"$unit".service ]; then
    ln -s ~/dotfiles/systemd/"$unit".service ~/.config/systemd/user/"$unit".service
    ln -s ~/dotfiles/systemd/"$unit".timer ~/.config/systemd/user/"$unit".timer
    systemctl --user daemon-reload
    systemctl --user enable --now "$unit".timer
    echo "$unit.timerを有効化しました"
  else
    echo "$unit.timer はリンク済みです。スキップします。"
  fi
done
# login-tab-checkはOnCalendarタイマーではなく、ログインのたびに確実に走るよう
# graphical-session.targetに直接フックしている(WantedBy指定のservice単体)
if [ ! -e ~/.config/systemd/user/login-tab-check.service ]; then
  ln -s ~/dotfiles/systemd/login-tab-check.service ~/.config/systemd/user/login-tab-check.service
  systemctl --user daemon-reload
  systemctl --user enable login-tab-check.service
  echo "login-tab-check.serviceを有効化しました"
else
  echo "login-tab-check.service はリンク済みです。スキップします。"
fi
echo "(bukuで対象URLに'notion_check'/'attendance_check'/'slack_check'/'schedule_check'/'mail_check'タグを付けてください)"
echo "(login-tab-checkは平日のログイン時のみ実行されます)"

echo "=== ログイン時の自動起動(WezTerm/Chrome/xhost-docker) ==="
mkdir -p ~/.config/autostart
for app in wezterm google-chrome xhost-docker; do
  if [ ! -e ~/.config/autostart/"$app".desktop ]; then
    ln -s ~/dotfiles/autostart/"$app".desktop ~/.config/autostart/"$app".desktop
    echo "$app.desktopをリンクしました"
  else
    echo "$app.desktop はリンク済みです。スキップします。"
  fi
done

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
