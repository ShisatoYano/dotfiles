# ghq管理下のリポジトリをfzfであいまい検索して移動する
gcd() {
  local dir
  dir=$(ghq list -p | fzf) || return
  cd "$dir" || return
}
