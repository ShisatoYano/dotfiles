# ghq管理下のリポジトリをfzfであいまい検索して移動する
gcd() {
  local dir
  dir=$(ghq list -p | fzf) || return
  cd "$dir" || return
}

# bukuのブックマークをfzfであいまい検索してブラウザで開く
bb() {
  local url
  url=$(buku --nostdin -p -f4 --nc | fzf --reverse --preview "buku --nostdin -p {1} --nc" --preview-window=wrap | cut -f2) || return
  [ -n "$url" ] && xdg-open "$url" >/dev/null 2>&1 &
}
