#!/usr/bin/env bash
# ステージ済みのdiffからAI(claude -p)でConventional Commitsのtype/subjectを判定し、
# git-czに渡す。scope/breaking changes/issuesは今まで通り対話入力のまま。
# 第1引数を渡すとbodyとしてそのまま渡す(ai-squash-commit.shが元コミット一覧を渡す用)。
set -euo pipefail

# lazygitのcustomCommandは非対話シェル(bash -c)で実行され.bashrcを読まないため、
# NVM経由のclaudeコマンドにPATHが通っていない。ここで明示的に読み込む
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

body="${1:-}"

diff=$(git diff --staged)
if [ -z "$diff" ]; then
  echo "ステージされた変更がありません" >&2
  exit 1
fi

result=$(echo "$diff" | claude -p "以下のgit diffを読んで、Conventional Commitsのtype(chore/ci/docs/feat/fix/perf/refactor/release/style/testのいずれか)と、変更内容を簡潔に表す1行のsubject(英語、命令形、絵文字なし)を判定してください。出力は以下の2行のみとし、それ以外の説明は付けないでください。
type: <type>
subject: <subject>")

type=$(echo "$result" | grep -oP '(?<=^type: ).*' | head -1 | tr -d '[:space:]')
subject=$(echo "$result" | grep -oP '(?<=^subject: ).*' | head -1)

if [ -z "$type" ] || [ -z "$subject" ]; then
  echo "AIによる生成に失敗しました: $result" >&2
  exit 1
fi

if [ -n "$body" ]; then
  # git-cz(minimist)は"--flag 値"のスペース区切りだと、値が"-"で始まる場合に
  # 誤って別のフラグとして分解してしまうため、"--flag=値"のイコール区切りで渡す
  exec git cz --type="$type" --subject="$subject" --body="$body"
else
  exec git cz --type="$type" --subject="$subject"
fi
