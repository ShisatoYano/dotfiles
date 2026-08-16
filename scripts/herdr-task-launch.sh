#!/usr/bin/env bash
# 1タスク分のClaude Codeエージェントを、隔離されたgit worktree上でHerdrに展開する。
# 並列化はこのスクリプト自身では持たない。呼び出し元(オーケストレーター役のClaude)が
# 同一ターン内で複数のBashツール呼び出しとしてこれを並列発行することを前提にしている。
# worktree自体はscripts/wezterm-worktree.sh(git worktree作成・サブモジュール初期化・
# registry管理・flockによる並列書き込み対応済み)にそのまま委譲する。
set -euo pipefail

WEZTERM_WORKTREE_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/wezterm-worktree.sh"
WORKTREES_ROOT="${HOME}/worktrees"

usage() {
  echo "使い方: $(basename "$0") <repo_root> <name> <purpose> <initial_prompt> [--anchor <workspace_id>]" >&2
  echo "  --anchorを省略すると、repo_root直下を指すHerdr workspaceを新規作成して使う。" >&2
  echo "  複数タスクを並列起動する場合は、最初に1回だけanchorを作って使い回すこと" >&2
  echo "  (省略時オートで作ると、タスクごとに重複したworkspaceができてしまうため)。" >&2
  exit 1
}

[ "$#" -ge 4 ] || usage

repo_root="$1" name="$2" purpose="$3" initial_prompt="$4"
shift 4
anchor=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --anchor) anchor="$2"; shift 2 ;;
    *) usage ;;
  esac
done

repo_name="$(basename "${repo_root%/}")"
worktree_path="${WORKTREES_ROOT}/${name}/${repo_name}"

echo "[${name}] worktreeを作成しています: ${worktree_path}" >&2
"$WEZTERM_WORKTREE_SCRIPT" create "$repo_root" "$worktree_path" "$name" "$purpose" >&2

if [ -z "$anchor" ]; then
  echo "[${name}] anchor workspace未指定のため新規作成します" >&2
  anchor_json=$(herdr workspace create --cwd "$repo_root" --label "${repo_name}-anchor" --no-focus)
  anchor=$(echo "$anchor_json" | jq -r '.result.workspace.workspace_id')
fi

echo "[${name}] Herdrにworktreeを開いています(anchor=${anchor})" >&2
open_json=$(herdr worktree open --workspace "$anchor" --path "$worktree_path" --label "$purpose" --no-focus)
pane_id=$(echo "$open_json" | jq -r '.result.root_pane.pane_id')

echo "[${name}] Claude Codeエージェントを起動しています(pane=${pane_id})" >&2
# 複数タスクを同時にworktree openした直後は、wezterm側のウィンドウ生成が
# 間に合わずagent startが一時的に"agent_pane_busy"で失敗することがある
# (単発実行やタイミングがずれた場合は起きない、実際に並列2つ発行して再現した事象)。
# 数秒おきに数回リトライすることで、この一過性の失敗を吸収する。
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

# agent startが成功=interactive_ready:trueでも、Claude Code自身の起動アニメーションが
# 終わる前だとプロンプト送信を取りこぼすことがある(1回だけ単発実行した際に再現)。
# --waitを付けると、状態変化が一定時間内に観測できない場合agent_prompt_stalledで
# 失敗を返してくれるので、それを目印にリトライする。--untilは指定せず、
# idle/done/blockedいずれかへの到達をデフォルトの完了条件として使う
# (--until workingにすると、一瞬で終わるタスクでworkingを観測できず誤検知するため)
attempt=0
until herdr agent prompt "$name" "$initial_prompt" --wait --timeout 10000 >&2; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 5 ]; then
    echo "[${name}] agent promptが${attempt}回失敗しました。諦めます" >&2
    exit 1
  fi
  echo "[${name}] agent promptの送信確認が取れず、2秒後にリトライします(${attempt}/5)" >&2
  sleep 2
done

jq -n --arg name "$name" --arg pane_id "$pane_id" --arg anchor "$anchor" \
      --arg worktree_path "$worktree_path" --arg purpose "$purpose" \
      '{name: $name, pane_id: $pane_id, anchor_workspace_id: $anchor, worktree_path: $worktree_path, purpose: $purpose}'
