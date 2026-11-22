#!/usr/bin/env bash
# WezTermのタブにClaude Codeの止まり(エラー・待ち)を出すための状態ファイルを書く/消す
# usage: wezterm-tab-state.sh error|waiting|idle|resume|clear
#   error/waiting: <pane>.<状態> を書き、BELでタブを描き直させる
#   idle: <pane>.idle を書くだけ(タブ表示に使わず通知だけに使うのでBELは出さない。出すと毎回ビープが鳴る)
#   resume: 待ちとidleだけ消す(ツールが動き出した・応答が終わった)
#   clear: すべて消す(入力・セッションの開始と終了)
# terminalSequenceはOSC 1337(SetUserVar)を許可しないため、ペインIDごとのファイルで受け渡す
[ -n "$WEZTERM_PANE" ] || exit 0
dir="${XDG_RUNTIME_DIR:-/tmp}/claude-tab-state"
base="$dir/$WEZTERM_PANE"

case "$1" in
  error | waiting)
    mkdir -p "$dir" && echo "$1" >"$base.$1"
    # ファイルを書いただけではタブが再描画されないため、BELを出させて描き直しを促す
    printf '{"terminalSequence": "\\u0007"}\n'
    ;;
  idle) mkdir -p "$dir" && echo idle >"$base.idle" ;;
  # 並行実行中は別ツールの完了で、権限確認中でも待ちが消える(フック入力では区別できない)
  resume) rm -f "$base.waiting" "$base.idle" ;;
  # 拡張子なしの $base は旧形式のエラーファイル。更新前から残っているものも消す
  clear) rm -f "$base" "$base.error" "$base.waiting" "$base.idle" ;;
esac
exit 0
