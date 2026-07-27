# ghq管理下のリポジトリをfzfであいまい検索して移動する
gcd() {
  local dir
  dir=$(ghq list -p | fzf) || return
  cd "$dir" || return
}

# bukuのブックマークをfzfであいまい検索してブラウザで開く(Tabキーで複数選択可)
bb() {
  local urls
  urls=$(buku --nostdin -p -f4 --nc | fzf --reverse --multi --preview "buku --nostdin -p {1} --nc" --preview-window=wrap | cut -f2) || return
  [ -n "$urls" ] || return
  while IFS= read -r url; do
    xdg-open "$url" >/dev/null 2>&1 &
  done <<< "$urls"
}

# 開いているタブをfzfであいまい検索して切り替える(IDは表示せずタイトル/URLだけで検索)
ta() {
  local id
  id=$(tabctl list | fzf --reverse --delimiter="\t" --with-nth=2,3 | cut -f1) || return
  [ -n "$id" ] && tabctl activate "$id"
}

# 開いているタブをfzfであいまい検索して選択したものを閉じる(Tabキーで複数選択可)
tc() {
  tabctl list | fzf --reverse --multi --delimiter="\t" --with-nth=2,3 | cut -f1 | xargs -r tabctl close
}

# 標準入力からタブ(id\ttitle\turl)を受け取り、bukuに保存してから閉じる共通処理
# 比較はURLのみで行う(タブタイトルは未読件数などで頻繁に変わり、
# 保存済みブックマークのタイトルとは一致しないことが多いため)
_tabarchive_process() {
  local existing
  existing=$(buku --nostdin -p -f1 --nc | cut -f2)
  while IFS=$'\t' read -r id title url; do
    if grep -Fxq "$url" <<< "$existing"; then
      echo "skip (既存): $title"
    else
      buku --nostdin -a "$url" tab-archive
    fi
    tabctl close "$id"
  done
}

# 選択したタブをbukuに保存してから閉じる(Tabキーで複数選択可)
tabarchive() {
  tabctl list | fzf --reverse --multi --delimiter="\t" --with-nth=2,3 | _tabarchive_process
}

# 開いている全タブをbukuに保存してから閉じる
tabarchive-all() {
  tabctl list | _tabarchive_process
}

# 指定ディレクトリ以下のファイルをfdfindで再帰的に検索し、fzfで選んだパスを出力する
# (省略時はカレントディレクトリ以下)
ff() {
  local dir="${1:-.}"
  fdfind --type f . "$dir" | fzf
}

# docker composeの短縮形(dc up -d, dc exec <service> bash, dc down等)
alias dc="docker compose"

# 起動中のコンテナをfzfであいまい検索してbashで入る
dexec() {
  local line container
  line=$(docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | fzf --reverse --header="NAMES	IMAGE	STATUS") || return
  container=$(cut -f1 <<< "$line")
  [ -n "$container" ] && docker exec -it "$container" bash
}

# 起動中のコンテナをfzfであいまい検索して停止する(Tabキーで複数選択可)
dstop() {
  docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | fzf --reverse --multi --header="NAMES	IMAGE	STATUS" | cut -f1 | xargs -r docker stop
}

# notify-relayが検知した通知をリアルタイムに表示する
alias nrlog="tail -f ~/.local/state/notify-relay/notify.log"

# カレンダー関連の通知(📅マーク付き)をあいまい検索し、
# Googleカレンダーのタブを開く/アクティブにする(実イベントへのリンクは通知に含まれないため)
nrjump() {
  grep '📅' ~/.local/state/notify-relay/notify.log 2>/dev/null \
    | tac \
    | fzf --reverse --prompt="カレンダー通知> " >/dev/null || return
  ~/dotfiles/scripts/tab-check.sh schedule_check
}

# 自分に関するPRを横断で確認する(自分が出したもの/レビュー依頼が来ているもの)
prs() {
  echo "=== 自分が出したPR ==="
  gh search prs --author @me --state open
  echo
  echo "=== 自分がレビュアーのPR ==="
  gh search prs --review-requested @me --state open
}
