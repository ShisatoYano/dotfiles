#!/usr/bin/env bash
# gh dashのカスタムキーバインドから呼ばれ、PRの差分中の特定行にレビューコメントを付ける。
# 使い方: gh-pr-comment.sh <owner/repo> <PR番号>
set -euo pipefail

repo="$1"
number="$2"

file=$(gh pr diff "$number" --repo "$repo" --name-only | fzf --prompt="コメントするファイル> ") || exit 0
[ -n "$file" ] || exit 0

read -r -p "行番号(diffの行番号ガター表示に合わせる): " line
[ -n "$line" ] || exit 0

read -r -p "side [R=追加後/新しい行(デフォルト) / L=削除前/古い行]: " side_input
case "$side_input" in
  [Ll]) side="LEFT" ;;
  *) side="RIGHT" ;;
esac

commit_id=$(gh pr view "$number" --repo "$repo" --json headRefOid -q .headRefOid)

tmp=$(mktemp --suffix=.md)
"${EDITOR:-nvim}" "$tmp"
body=$(cat "$tmp")
rm -f "$tmp"

if [ -z "$body" ]; then
  echo "本文が空のため中止しました"
  read -r -n 1 -s -p "(Enterで閉じます)"
  exit 0
fi

if response=$(gh api "repos/$repo/pulls/$number/comments" \
  -f body="$body" -f commit_id="$commit_id" -f path="$file" -F "line=$line" -f side="$side" 2>&1); then
  echo "コメントしました: $(echo "$response" | jq -r .html_url)"
else
  echo "投稿に失敗しました:"
  echo "$response"
fi
read -r -n 1 -s -p "(Enterで閉じます)"
