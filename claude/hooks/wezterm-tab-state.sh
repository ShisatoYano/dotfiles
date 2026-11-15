#!/usr/bin/env bash
# WezTermのタブにClaude Codeのエラー停止を出すための状態ファイルを書く/消す
# usage: wezterm-tab-state.sh error|clear
# terminalSequenceはOSC 1337(SetUserVar)を許可しないため、ペインIDごとのファイルで受け渡す
[ -n "$WEZTERM_PANE" ] || exit 0
dir="${XDG_RUNTIME_DIR:-/tmp}/claude-tab-state"

case "$1" in
  error)
    mkdir -p "$dir" && echo error >"$dir/$WEZTERM_PANE"
    # ファイルを書いただけではタブが再描画されないため、BELを出させて描き直しを促す
    printf '{"terminalSequence": "\\u0007"}\n'
    ;;
  clear) rm -f "$dir/$WEZTERM_PANE" ;;
esac
exit 0
