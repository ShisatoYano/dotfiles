#!/usr/bin/env bash
# 1タスク分のClaude Codeエージェントを、隔離されたgit worktree上でHerdrに展開する。
# 並列化はこのスクリプト自身では持たない。呼び出し元(オーケストレーター役のClaude)が
# 同一ターン内で複数のBashツール呼び出しとしてこれを並列発行することを前提にしている。
#
# worktree作成はHerdr自身の`herdr worktree create --cwd`に一本化している(以前は
# scripts/wezterm-worktree.sh経由だったが、Herdrが--cwd直指定でworktree作成から
# ペイン確保までできることが分かったため統合した。anchor workspaceの事前作成も不要)。
# サブモジュール初期化はここでは行わない。委譲先エージェントには初期プロンプトで
# 「作業前に必ずリポジトリのセットアップ完了をユーザーに確認する」よう指示する設計
# (daily-task-planning Skill側)のため、サブモジュール初期化が必要な場合もその中で扱われる。
set -euo pipefail

WORKTREES_ROOT="${HOME}/worktrees"

usage() {
  echo "使い方: $(basename "$0") <repo_root> <name> <purpose> <initial_prompt> [--base <ref>]" >&2
  echo "  nameはHerdr上のagent名・新規ブランチ名・worktreeディレクトリ名を兼ねる(例: task-4595)" >&2
  echo "  --baseを省略すると、repo_rootの現在のHEADを起点に新規ブランチを作る" >&2
  exit 1
}

[ "$#" -ge 4 ] || usage

repo_root="$1" name="$2" purpose="$3" initial_prompt="$4"
shift 4
base=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --base) base="$2"; shift 2 ;;
    *) usage ;;
  esac
done

repo_name="$(basename "${repo_root%/}")"
worktree_path="${WORKTREES_ROOT}/${name}/${repo_name}"

echo "[${name}] Herdrでworktreeを作成しています: ${worktree_path}" >&2
create_args=(--cwd "$repo_root" --path "$worktree_path" --branch "$name" --label "$purpose" --no-focus)
[ -n "$base" ] && create_args+=(--base "$base")
create_json=$(herdr worktree create "${create_args[@]}")
pane_id=$(echo "$create_json" | jq -r '.result.root_pane.pane_id')
workspace_id=$(echo "$create_json" | jq -r '.result.workspace.workspace_id')

echo "[${name}] Claude Codeエージェントを起動しています(pane=${pane_id})" >&2
# worktree作成直後は、wezterm側のウィンドウ生成が間に合わずagent startが一時的に
# "agent_pane_busy"で失敗することがある(単発実行やタイミングがずれた場合は起きない、
# 実際に並列2つ発行して再現した事象)。数秒おきに数回リトライすることで吸収する。
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

jq -n --arg name "$name" --arg pane_id "$pane_id" --arg workspace_id "$workspace_id" \
      --arg worktree_path "$worktree_path" --arg purpose "$purpose" \
      '{name: $name, pane_id: $pane_id, workspace_id: $workspace_id, worktree_path: $worktree_path, purpose: $purpose}'
