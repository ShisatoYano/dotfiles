#!/usr/bin/env bash
# PRの一覧を、作業ディレクトリのリポジトリとそのサブモジュールに絞って返す。LLMを使わずに変化の有無も判定する
# usage: pr-scope.sh list|check|done [dir|--all]
#   list : 対象リポジトリのPR一覧(自分のPR・レビュー依頼・レビュー済み)と、対象外の件数をJSONで出す
#   check: PRの状態の指紋を前回と比べて changed / unchanged を出し、巡回時刻(heartbeat)を書く
#   done : 巡回を最後まで処理できたときだけ、checkの指紋を「前回」として保存する
# gitリポジトリの外か --all のときは全リポジトリを対象にする
set -euo pipefail
# 既定ではコマンド置換の中で-eが外れ、ghの失敗が空の結果として素通りするため
shopt -s inherit_errexit

cmd="${1:-}"
dir="${2:-$PWD}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code/pr-watch"

# github.comのURLを owner/repo にする(github.com以外は空)
slug_of_url() {
  local url="${1%/}"
  url="${url%.git}"
  case "$url" in
    git@github.com:*) echo "${url#git@github.com:}" ;;
    https://github.com/* | http://github.com/*) echo "${url#*://github.com/}" ;;
    ssh://git@github.com/*) echo "${url#ssh://git@github.com/}" ;;
  esac
}

# サブモジュールの相対URL(../foo.git)を、親リポジトリのowner/repoを基準に解決する
resolve_url() {
  local parent="$1" url="$2"
  case "$url" in
    ../*)
      local base="$parent" out
      while [ "${url#../}" != "$url" ]; do
        url="${url#../}"
        if [[ "$base" == */* ]]; then base="${base%/*}"; else base=""; fi
      done
      out="${base:+$base/}${url%.git}"
      if [[ "$out" =~ ^[^/]+/[^/]+$ ]]; then echo "$out"; fi
      ;;
    *) slug_of_url "$url" ;;
  esac
}

# .gitmodulesを再帰的にたどる。未初期化のサブモジュールも.gitmodulesのURLは拾い、中は初期化済みのものだけ見る
collect_submodules() {
  local repo_dir="$1" parent="$2" key url path slug
  [ -f "$repo_dir/.gitmodules" ] || return 0
  while read -r key url; do
    path=$(git config -f "$repo_dir/.gitmodules" --get "${key%.url}.path" || true)
    slug=$(resolve_url "$parent" "$url")
    [ -n "$slug" ] || continue
    echo "$slug"
    if [ -n "$path" ] && [ -e "$repo_dir/$path/.git" ]; then
      collect_submodules "$repo_dir/$path" "$slug"
    fi
  done < <(git config -f "$repo_dir/.gitmodules" --get-regexp '^submodule\..*\.url$' || true)
}

root=""
if [ "$dir" != "--all" ]; then
  root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)
fi
scope_json='[]'
key=all
note=""
if [ -n "$root" ]; then
  origin=$(slug_of_url "$(git -C "$root" remote get-url origin 2>/dev/null || true)")
  if [ -n "$origin" ]; then
    # URLは小文字で書かれがちだが、ghは正式な表記(大文字を含む)で返すため、小文字にそろえて比べる
    scope_json=$({ echo "$origin"; collect_submodules "$root" "$origin"; } | tr '[:upper:]' '[:lower:]' | sort -u | jq -R . | jq -sc .)
    key=$(tr '[:upper:]' '[:lower:]' <<<"${origin/\//+}")
  else
    note="originがgithub.comのURLとして読めないため、全リポジトリを対象にした"
  fi
fi
LIMIT=100

list_json() {
  local fields=number,repository,title,url,isDraft,updatedAt mine review reviewed
  mine=$(gh search prs --author @me --state open --limit "$LIMIT" --json "$fields")
  review=$(gh search prs --review-requested @me --state open --sort updated --order asc --limit "$LIMIT" --json "$fields")
  reviewed=$(gh search prs --reviewed-by @me --state open --limit "$LIMIT" --json "$fields" -- -author:@me)
  jq -n --argjson scope "$scope_json" --arg root "$root" --arg note "$note" --argjson limit "$LIMIT" \
    --argjson mine "$mine" --argjson review "$review" --argjson reviewed "$reviewed" '
    def slim: map({repo: .repository.nameWithOwner, number, title, url, isDraft, updatedAt});
    def hit: (.repo | ascii_downcase) as $r | $scope | index($r);
    def inscope: if ($scope | length) == 0 then . else map(select(hit)) end;
    def outscope: if ($scope | length) == 0 then [] else map(select(hit | not)) end;
    ($mine | slim) as $m | ($review | slim) as $rq
    | ($reviewed | slim | map(select(. as $p | $rq | any(.repo == $p.repo and .number == $p.number) | not))) as $rv
    | {repo_root: $root, scope: $scope, all: (($scope | length) == 0),
       mine: ($m | inscope), review_requested: ($rq | inscope), reviewed_by: ($rv | inscope),
       others: {mine: ($m | outscope | length), review_requested: ($rq | outscope | length)},
       # 件数が上限に達した検索は、絞り込む前に対象のPRが欠けている可能性がある
       truncated: ([["mine", $mine], ["review_requested", $review], ["reviewed_by", $reviewed]]
                   | map(select((.[1] | length) >= $limit) | .[0]))}
    + (if $note == "" then {} else {note: $note} end)'
}

# CIの完了ではPRの更新時刻が変わらないことがあるため、自分のPRはhead・CI・レビュー判定まで指紋に入れる
fingerprint() {
  local list="$1" repo number detail details='[]'
  while read -r repo number; do
    detail=$(gh pr view "$number" --repo "$repo" --json headRefOid,statusCheckRollup,reviewDecision,mergeStateStatus \
      --jq '{head: .headRefOid, decision: .reviewDecision, merge: .mergeStateStatus,
             checks: ([.statusCheckRollup[] | if (.conclusion // "") != "" then .conclusion else (.state // .status) end] | sort)}')
    details=$(jq -c --arg repo "$repo" --argjson n "$number" --argjson d "$detail" '. + [{repo: $repo, number: $n} + $d]' <<<"$details")
  done < <(jq -r '.mine[] | "\(.repo) \(.number)"' <<<"$list")
  # 検索結果の並び順が変わっただけでchangedにならないよう、並べ替えてから指紋にする
  jq -cS --argjson details "$details" 'def key: sort_by(.repo, .number); {
      mine: ([.mine[] | {repo, number, updatedAt}] | key), details: ($details | key),
      review: ([.review_requested[] | {repo, number, updatedAt}] | key),
      reviewed: ([.reviewed_by[] | {repo, number, updatedAt}] | key)}' <<<"$list" |
    sha256sum | cut -d' ' -f1
}

case "$cmd" in
  list) list_json ;;
  check)
    mkdir -p "$state_dir"
    # heartbeatは巡回が動いていることを示すので、ghの失敗より先に書く
    date +%s >"$state_dir/$key.heartbeat"
    # 前の回の失敗で残ったpendingを、この回のdoneが保存しないよう先に消す
    rm -f "$state_dir/$key.pending"
    list=$(list_json)
    [ -n "$list" ] || { echo "pr-scope: empty PR list" >&2; exit 1; }
    fp=$(fingerprint "$list")
    echo "$fp" >"$state_dir/$key.pending"
    if [ "$fp" = "$(cat "$state_dir/$key.fp" 2>/dev/null || true)" ]; then echo unchanged; else echo changed; fi
    ;;
  done)
    if [ -f "$state_dir/$key.pending" ]; then mv "$state_dir/$key.pending" "$state_dir/$key.fp"; fi
    ;;
  *)
    echo "usage: pr-scope.sh list|check|done [dir|--all]" >&2
    exit 2
    ;;
esac
