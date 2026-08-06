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

# git-czが認識する正規のtype一覧。この一覧に無いtypeを渡すと、git-cz内部で
# config.types[type].emoji が undefined になりTypeErrorでクラッシュするため、
# プロンプトへの指示とバリデーションの両方をこの配列で揃える
VALID_TYPES=(chore ci docs feat fix perf refactor release style test)
VALID_TYPES_LIST=$(IFS=/; echo "${VALID_TYPES[*]}")

result=$(echo "$diff" | claude -p "以下のgit diffを読んで、Conventional Commitsのtype(${VALID_TYPES_LIST}のいずれか)と、変更内容を簡潔に表す1行のsubject(英語、命令形、絵文字なし)を判定してください。出力は以下の2行のみとし、それ以外の説明は付けないでください。
type: <type>
subject: <subject>")

# .*ではなく[a-z]+に限定し、AIが型名の後に余計な文字を続けた場合に
# 空白除去でtypeが壊れた文字列にならないようにする
type=$(echo "$result" | grep -oP '(?<=^type: )[a-z]+' | head -1)
subject=$(echo "$result" | grep -oP '(?<=^subject: ).*' | head -1)

if [ -z "$type" ] || [ -z "$subject" ]; then
  echo "AIによる生成に失敗しました: $result" >&2
  exit 1
fi

if [[ ! " ${VALID_TYPES[*]} " == *" $type "* ]]; then
  echo "AIが不正なtypeを返しました: '$type'(期待値: ${VALID_TYPES_LIST})" >&2
  exit 1
fi

if [ -n "$body" ]; then
  # git-cz(minimist)は"--flag 値"のスペース区切りだと、値が"-"で始まる場合に
  # 誤って別のフラグとして分解してしまうため、"--flag=値"のイコール区切りで渡す
  exec git cz --type="$type" --subject="$subject" --body="$body"
else
  exec git cz --type="$type" --subject="$subject"
fi
