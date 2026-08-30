#!/usr/bin/env bash
# git worktreeベースの目的別ワークスペースを管理するバックエンド。
# wezterm/config/worktree_workspace.luaから呼び出される想定で、UIは持たず
# git操作とregistry(JSON)の読み書きに専念する。
#
# registryは "workspace名(=目的名) -> {repo_root, worktree_path, purpose, created_at}" の
# 単純なJSONオブジェクト。ブランチ名はworktree作成後に自分でchekoutして変わっていくため
# 保存せず、list時にその場でgit問い合わせして返す。
set -euo pipefail

REGISTRY_DIR="${HOME}/.local/share/wezterm-worktrees"
REGISTRY_FILE="${REGISTRY_DIR}/registry.json"
REGISTRY_LOCK="${REGISTRY_DIR}/registry.lock"

usage() {
  echo "使い方: $(basename "$0") <create|remove|list|check-dirty> ..." >&2
  exit 1
}

ensure_registry() {
  mkdir -p "$REGISTRY_DIR"
  [ -f "$REGISTRY_FILE" ] || echo '{}' > "$REGISTRY_FILE"
}

# 対象ディレクトリ配下(サブモジュール含め再帰的に)未コミットの変更があるか調べる。
# worktree作成前の警告と削除前の安全確認の両方で使う共通ロジック。
has_uncommitted_changes() {
  local path="$1"
  if [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then
    return 0
  fi
  if [ -f "$path/.gitmodules" ]; then
    local sub_status
    sub_status=$(git -C "$path" submodule foreach --recursive --quiet 'git status --porcelain' 2>/dev/null || true)
    [ -n "$sub_status" ] && return 0
  fi
  return 1
}

cmd_check_dirty() {
  local path="$1"
  if has_uncommitted_changes "$path"; then
    echo "dirty"
    exit 1
  fi
  echo "clean"
  exit 0
}

cmd_create() {
  local repo_root="$1" worktree_path="$2" workspace_name="$3" purpose="$4"
  ensure_registry

  # 複数タスクを並列でcreateする運用を想定し、registry.jsonへの
  # 存在チェック・書き込みはflockで直列化する。git worktree add/サブモジュール初期化は
  # ロックの外で行うため、並列実行時の速度メリット自体は損なわれない
  exec {lock_fd}>"$REGISTRY_LOCK"
  flock -x "$lock_fd"
  if jq -e --arg n "$workspace_name" 'has($n)' "$REGISTRY_FILE" >/dev/null; then
    flock -u "$lock_fd"
    echo "エラー: workspace '$workspace_name' は既に存在します" >&2
    exit 1
  fi
  flock -u "$lock_fd"

  # 前回のcreate失敗時に残った、登録だけされて実体が無いworktreeを掃除しておく
  # (残っているとこの後のworktree addが「missing but already registered」で失敗する)
  git -C "$repo_root" worktree prune

  mkdir -p "$(dirname "$worktree_path")"
  echo "worktreeを作成しています: $worktree_path"
  # 現在のHEADコミット位置をdetachedで引き継ぐ(同じブランチを複数worktreeで
  # 同時チェックアウトできないため)。ブランチを切るかどうかは作成後に利用者が判断する。
  git -C "$repo_root" worktree add --detach "$worktree_path"

  # ここから先で失敗した場合、worktree登録だけ残って再実行時に衝突するのを防ぐため
  # add済みのworktreeを片付けてから抜ける
  trap 'git -C "$repo_root" worktree remove --force "$worktree_path" 2>/dev/null || true' ERR

  if [ -f "$worktree_path/.gitmodules" ]; then
    # `submodule update --init --recursive`を一括で呼ぶと、LFS込みの大きいサブモジュールが
    # 1つあるだけで数分間も無出力になり「止まっているのか」判断できない。
    # サブモジュール1つずつ回して、どれを処理中か・全体の何個目かを都度表示する
    local total i=0 sm_path
    total=$(git -C "$worktree_path" submodule status | wc -l)
    echo "サブモジュールを初期化しています(${total}件。LFSデータを含むものは1件だけで数分かかることがあります)"
    while IFS= read -r sm_path; do
      i=$((i + 1))
      echo "[${i}/${total}] ${sm_path} を初期化中..."
      git -C "$worktree_path" submodule update --init --recursive -- "$sm_path"
    done < <(git -C "$worktree_path" submodule status | awk '{print $2}')
  fi

  local created_at tmp
  created_at=$(date -Iseconds)
  flock -x "$lock_fd"
  tmp=$(mktemp)
  jq --arg n "$workspace_name" \
     --arg repo "$repo_root" \
     --arg path "$worktree_path" \
     --arg purpose "$purpose" \
     --arg created "$created_at" \
     '.[$n] = {repo_root: $repo, worktree_path: $path, purpose: $purpose, created_at: $created}' \
     "$REGISTRY_FILE" > "$tmp"
  mv "$tmp" "$REGISTRY_FILE"
  flock -u "$lock_fd"
  trap - ERR

  echo "作成しました: $worktree_path"
}

cmd_remove() {
  local workspace_name="$1"
  ensure_registry

  exec {lock_fd}>"$REGISTRY_LOCK"
  flock -x "$lock_fd"
  local entry
  entry=$(jq -e --arg n "$workspace_name" '.[$n]' "$REGISTRY_FILE") || {
    flock -u "$lock_fd"
    echo "エラー: workspace '$workspace_name' は見つかりません" >&2
    exit 1
  }
  flock -u "$lock_fd"
  local repo_root worktree_path
  repo_root=$(echo "$entry" | jq -r '.repo_root')
  worktree_path=$(echo "$entry" | jq -r '.worktree_path')

  if has_uncommitted_changes "$worktree_path"; then
    echo "エラー: 未コミットの変更が残っています。削除を中止しました: $worktree_path" >&2
    exit 1
  fi

  # サブモジュールを含むworktreeは素の`worktree remove`では拒否されるため--forceを使う。
  # 未コミット変更はここまでの直前チェックで確認済みなので、安全性は損なわれない。
  git -C "$repo_root" worktree remove --force "$worktree_path"

  # worktree_pathはcreate時にmkdir -pした「目的名/リポジトリ名」の2階層構成。
  # worktree removeはリポジトリ名側のディレクトリしか消さないため、目的名側の
  # 親ディレクトリが空の抜け殻として残る。空であれば片付ける
  # (他リポジトリのworktreeが同じ目的名配下に残っていれば空にならず、rmdirは黙って失敗する)
  rmdir "$(dirname "$worktree_path")" 2>/dev/null || true

  flock -x "$lock_fd"
  local tmp
  tmp=$(mktemp)
  jq --arg n "$workspace_name" 'del(.[$n])' "$REGISTRY_FILE" > "$tmp"
  mv "$tmp" "$REGISTRY_FILE"
  flock -u "$lock_fd"

  echo "削除しました: $workspace_name"
}

cmd_list() {
  ensure_registry
  jq -c 'to_entries[]' "$REGISTRY_FILE" | while IFS= read -r entry; do
    local path branch
    path=$(echo "$entry" | jq -r '.value.worktree_path')
    if [ -d "$path" ]; then
      branch=$(git -C "$path" symbolic-ref --short HEAD 2>/dev/null || git -C "$path" rev-parse --short HEAD 2>/dev/null || echo "?")
    else
      branch="(missing)"
    fi
    echo "$entry" | jq -c --arg branch "$branch" '.value + {name: .key, current_branch: $branch}'
  done | jq -s '.'
}

case "${1:-}" in
  create) shift; cmd_create "$@" ;;
  remove) shift; cmd_remove "$@" ;;
  list) shift; cmd_list "$@" ;;
  check-dirty) shift; cmd_check_dirty "$@" ;;
  *) usage ;;
esac
