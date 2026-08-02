#!/bin/bash
# Claude Code statusline: モデル名 + コンテキスト使用率 + サブスクリプション利用率(5h/7d) + ディレクトリ名
# コストの内訳(ccusage)は情報過多かつ幅の問題も出たため廃止し、本当に見たい情報だけに絞っている。
# 見た目は絵文字区切りでおしゃれに。

input=$(cat)

RESET="\033[0m"
C_MODEL="\033[38;5;141m" # purple
C_OK="\033[38;5;150m"    # green
C_WARN="\033[38;5;209m"  # orange
C_CRIT="\033[38;5;204m"  # pink
C_DIM="\033[38;5;245m"   # dim gray

model=$(echo "$input" | jq -r '.model.display_name // "?"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
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
fi

rl=""
[ -n "$five" ] && rl="5h $(printf '%.0f' "$five")%"
[ -n "$week" ] && rl="${rl:+$rl }7d $(printf '%.0f' "$week")%"
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
