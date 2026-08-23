#!/usr/bin/env bash
# 1タスク分のClaude Codeエージェントを、worktreeを作らずHerdrに展開する。
# herdr-task-launch.shのworktree版と異なり、編集・ブランチ作成を伴わない
# 調査・確認系のタスク(例: pr-workflow Skillの並列委譲)向け。
# 並列化はこのスクリプト自身では持たない。呼び出し元(オーケストレーター役のClaude)が
# 同一ターン内で複数のBashツール呼び出しとしてこれを並列発行することを前提にしている。
set -euo pipefail

usage() {
  echo "使い方: $(basename "$0") <repo_root> <name> <purpose> <initial_prompt>" >&2
  echo "  nameはHerdr上のagent名を兼ねる(例: pr-own-check)" >&2
  exit 1
}

[ "$#" -eq 4 ] || usage

repo_root="$1" name="$2" purpose="$3" initial_prompt="$4"

echo "[${name}] Herdrでworkspaceを作成しています(cwd=${repo_root})" >&2
create_json=$(herdr workspace create --cwd "$repo_root" --label "$purpose" --no-focus)
pane_id=$(echo "$create_json" | jq -r '.result.root_pane.pane_id')
workspace_id=$(echo "$create_json" | jq -r '.result.workspace.workspace_id')
# sidebar表示用の$idトークンを登録する(~/dotfiles/herdr/config.tomlの[ui.sidebar.spaces]と対)
herdr workspace report-metadata "$workspace_id" --source dotfiles --token "id=${workspace_id}" >/dev/null

echo "[${name}] Claude Codeエージェントを起動しています(pane=${pane_id})" >&2
# worktree作成直後と同様、workspace作成直後もwezterm側のウィンドウ生成が間に合わず
# agent startが一時的に"agent_pane_busy"で失敗することがあるため、リトライで吸収する
# (herdr-task-launch.shで実際に再現した事象と同じ経路のため踏襲)
attempt=0
until herdr agent start "$name" --kind claude --pane "$pane_id" >&2; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 5 ]; then
    echo "[${name}] agent startが${attempt}回失敗しました。諦めます" >&2
    exit 1
  fi
  echo "[${name}] agent startに失敗、2秒後にリトライします(${attempt}/5)" >&2
  sleep 2
done

# --untilを指定せずidle/done/blockedへの到達を待つと(herdr-task-launch.shと同じ設定)、
# この用途の初期プロンプトは実行に数十秒〜数分かかることが多く、10秒のtimeoutで
# 毎回タイムアウト→リトライしてプロンプトが二重送信されてしまう(実際に再現した)。
# ここでは「プロンプトが受理され実行が始まったこと」の確認だけで十分
# (完了そのものは委譲先からのSendMessage通知で追う設計のため)、
# --until workingで確認する。長時間タスク前提なのでworking遷移の見逃しは起きにくい
attempt=0
until herdr agent prompt "$name" "$initial_prompt" --wait --until working --timeout 10000 >&2; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 5 ]; then
    echo "[${name}] agent promptが${attempt}回失敗しました。諦めます" >&2
    exit 1
  fi
  echo "[${name}] agent promptの送信確認が取れず、2秒後にリトライします(${attempt}/5)" >&2
  sleep 2
done

jq -n --arg name "$name" --arg pane_id "$pane_id" --arg workspace_id "$workspace_id" \
      --arg repo_root "$repo_root" --arg purpose "$purpose" \
      '{name: $name, pane_id: $pane_id, workspace_id: $workspace_id, repo_root: $repo_root, purpose: $purpose}'
