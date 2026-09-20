#!/usr/bin/env bash
# 環境構築のブートストラップ。
# 実際の構築手順は ansible/local.yml 側にあり、ここはansibleを用意して流すだけ。
#
# 追加の引数はそのままansible-playbookへ渡す。例:
#   ./scripts/setup.sh --check          # 何が変わるかだけ見る(dry-run)
#   ./scripts/setup.sh --tags bins      # リリースバイナリの配置だけやり直す
#   ./scripts/setup.sh --list-tasks     # 実行される手順の一覧
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# npm/pipxモジュール(community.general)まで要るので、ansible-coreではなくansibleを入れる
if ! command -v ansible-playbook &> /dev/null; then
  echo "=== ansible をインストールします ==="
  sudo apt update
  sudo apt install -y ansible
fi

# sudoにパスワードが要る環境でだけ -K を付け、最初に一度だけ聞く
become_args=()
if ! sudo -n true 2> /dev/null; then
  become_args=(-K)
fi

echo "=== セットアップを開始します ==="
cd "$DOTFILES_DIR/ansible"
exec ansible-playbook "${become_args[@]}" local.yml "$@"
