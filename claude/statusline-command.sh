#!/bin/bash
# Claude Code statusline: モデル名 + コンテキスト使用率 + サブスクリプション利用率(5h/7d、リセットまでの残り時間付き) + ディレクトリ名
# コストの内訳(ccusage)は情報過多かつ幅の問題も出たため廃止し、本当に見たい情報だけに絞っている。
# 見た目は絵文字区切りでおしゃれに。

input=$(cat)

CONTEXT_WARN_DIR="${HOME}/.local/state/claude-code/context-warnings"

RESET="\033[0m"
C_MODEL="\033[38;5;141m" # purple
C_OK="\033[38;5;150m"    # green
C_WARN="\033[38;5;209m"  # orange
C_CRIT="\033[38;5;204m"  # pink
C_DIM="\033[38;5;245m"   # dim gray

model=$(echo "$input" | jq -r '.model.display_name // "?"')
session_id=$(echo "$input" | jq -r '.session_id // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')

# resets_at はUNIX epoch秒。現在時刻との差分を人間可読な残り時間に変換する。
now=$(date +%s)
fmt_remaining() {
  local epoch="$1"
  [ -z "$epoch" ] && return
  local diff=$(( epoch - now ))
  [ "$diff" -lt 0 ] && diff=0
  local d=$(( diff / 86400 ))
  local h=$(( (diff % 86400) / 3600 ))
  local m=$(( (diff % 3600) / 60 ))
  if [ "$d" -gt 0 ]; then
    printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then
    printf '%dh%dm' "$h" "$m"
  else
    printf '%dm' "$m"
  fi
}
dirname=""
[ -n "$cwd" ] && dirname=$(basename "$cwd")

parts=()
parts+=("🤖 ${C_MODEL}${model}${RESET}")

if [ -n "$used" ]; then
  used_int=${used%.*}
  color="$C_OK"
  [ "$used_int" -ge 50 ] && color="$C_WARN"
  [ "$used_int" -ge 80 ] && color="$C_CRIT"
  parts+=("🧠 ${color}$(printf '%.0f' "$used")%${RESET}")

  # 50%到達を warn-context-threshold.py hook(UserPromptSubmit)に伝えるためのマーカー。
  # statusLineはcontext_window.used_percentageを受け取れる唯一のhook種別なので、ここで検知して
  # ファイル経由でUserPromptSubmit hookに引き継ぐ(hookイベント自体はこの値を受け取れない)。
  if [ "$used_int" -ge 50 ] && [ -n "$session_id" ]; then
    mkdir -p "$CONTEXT_WARN_DIR"
    touch "${CONTEXT_WARN_DIR}/${session_id}"
  fi
fi

rl=""
if [ -n "$five" ]; then
  rl="5h $(printf '%.0f' "$five")%"
  fr=$(fmt_remaining "$five_reset")
  [ -n "$fr" ] && rl="${rl}→${fr}"
fi
if [ -n "$week" ]; then
  wr="7d $(printf '%.0f' "$week")%"
  fr=$(fmt_remaining "$week_reset")
  [ -n "$fr" ] && wr="${wr}→${fr}"
  rl="${rl:+$rl }${wr}"
fi
[ -n "$rl" ] && parts+=("⏳ ${C_DIM}${rl}${RESET}")

[ -n "$dirname" ] && parts+=("📁 ${C_DIM}${dirname}${RESET}")

output=""
for p in "${parts[@]}"; do
  if [ -z "$output" ]; then
    output="$p"
  else
    output="${output} ${C_DIM}│${RESET} ${p}"
  fi
done

printf "%b" "$output"
