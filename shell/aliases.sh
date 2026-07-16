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
