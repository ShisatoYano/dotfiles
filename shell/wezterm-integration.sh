# WezTermシェル統合(/etc/profile.d/wezterm.sh)をstarshipと共存させる。starship initより後にsourceすること
declare -F __wezterm_semantic_precmd >/dev/null || return 0

# 統合スクリプトはコマンド未実行のprecmd(空Enter・Ctrl+C)ではPS1に目印を付け直さないが、
# starshipは毎回PS1を作り直すため目印が消える。未実行時は二重実行ガードを解除してから呼ぶ
__wezterm_precmd_after_starship() {
  [[ "$__wezterm_semantic_precmd_executing" == "0" ]] && __wezterm_semantic_precmd_executing=""
  __wezterm_semantic_precmd
}

precmd_functions=("${precmd_functions[@]/#__wezterm_semantic_precmd}" __wezterm_precmd_after_starship)
