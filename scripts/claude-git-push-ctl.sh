#!/usr/bin/env bash
# claude/hooks/block-git-push.pyが参照するトグルファイルのon/off/toggleを行う。
# トグルファイルが存在する間だけ、そのフックはgit pushをブロックしない。
set -euo pipefail

STATE_DIR="${HOME}/.local/state/claude-git-push"
STATE_FILE="${STATE_DIR}/allowed"

usage() {
  echo "使い方: $(basename "$0") on|off|toggle" >&2
  exit 1
}

[ "$#" -eq 1 ] || usage

cmd_on() {
  mkdir -p "$STATE_DIR"
  touch "$STATE_FILE"
  echo "git pushを許可しました(${STATE_FILE})"
}

cmd_off() {
  rm -f "$STATE_FILE"
  echo "git pushを既定のブロックに戻しました"
}

case "$1" in
  on) cmd_on ;;
  off) cmd_off ;;
  toggle)
    if [ -e "$STATE_FILE" ]; then
      cmd_off
    else
      cmd_on
    fi
    ;;
  *) usage ;;
esac
