#!/usr/bin/env bash
# push前に、まだリモートに無いローカルコミットをまとめて1つにスカッシュし、
# ai-commit-msg.shに渡してtype/subjectをAIに判定させる。
# (reset --softなのでワーキングツリー/未コミットの変更には触れない)
# 元の細かいコミットメッセージは一覧化してbodyとして残す
# (GitHubのSquash and Mergeが本文に元コミット一覧を入れてくれるのと同じ見た目にするため)。
set -euo pipefail

base=""
if git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
  base=$(git merge-base '@{upstream}' HEAD)
else
  default_ref=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || true)
  if [ -n "$default_ref" ]; then
    base=$(git merge-base "$default_ref" HEAD 2>/dev/null || true)
  fi
fi

if [ -z "$base" ]; then
  echo "スカッシュ対象のベースコミットを特定できませんでした(upstream未設定、かつorigin/HEADも不明です)" >&2
  exit 1
fi

old_head=$(git rev-parse HEAD)
if [ "$base" = "$old_head" ]; then
  echo "スカッシュ対象のコミットがありません" >&2
  exit 0
fi

body=$(git log --format='- %s' "$base".."$old_head")

git reset --soft "$base"
exec "$(dirname "$0")/ai-commit-msg.sh" "$body"
