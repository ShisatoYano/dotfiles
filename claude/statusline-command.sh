#!/bin/bash
# Claude Code statusline: モデル名 / コンテキスト使用率 / 利用制限(5h・7d、リセットまでの残り時間) / ディレクトリ名 / gitブランチ

input=$(cat)

CONTEXT_WARN_DIR="${HOME}/.local/state/claude-code/context-warnings"

RESET=$'\033[0m'
C_MODEL=$'\033[38;5;141m' # purple
C_OK=$'\033[38;5;150m'    # green
C_WARN=$'\033[38;5;209m'  # orange
C_CRIT=$'\033[38;5;204m'  # pink
C_DIM=$'\033[38;5;245m'   # dim gray

# evalで代入される変数をshellcheckに知らせるための宣言(消すとSC2154が出る)
declare model session_id used five week five_reset week_reset cwd
eval "$(echo "$input" | jq -r '@sh "
model=\(.model.display_name // "?")
session_id=\(.session_id // "")
used=\(.context_window.used_percentage // "")
five=\(.rate_limits.five_hour.used_percentage // "")
week=\(.rate_limits.seven_day.used_percentage // "")
five_reset=\(.rate_limits.five_hour.resets_at // "")
week_reset=\(.rate_limits.seven_day.resets_at // "")
cwd=\(.workspace.current_dir // .cwd // "")
"')"

pct_color() {
  local p=${1%.*}
  if [ "$p" -ge 80 ]; then
    printf '%s' "$C_CRIT"
  elif [ "$p" -ge 50 ]; then
    printf '%s' "$C_WARN"
  else
    printf '%s' "$C_OK"
  fi
}

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

# 利用制限1枠分("5h 31%→2h3m")を、%部分だけ使用率に応じて色付けして返す
fmt_limit() {
  local label="$1" pct="$2" reset="$3"
  [ -z "$pct" ] && return
  local s r
  s="${C_DIM}${label} $(pct_color "$pct")$(printf '%.0f' "$pct")%${C_DIM}"
  r=$(fmt_remaining "$reset")
  [ -n "$r" ] && s="${s}→${r}"
  printf '%s' "${s}${RESET}"
}

parts=()
parts+=("🤖 ${C_MODEL}${model}${RESET}")

if [ -n "$used" ]; then
  parts+=("🧠 $(pct_color "$used")$(printf '%.0f' "$used")%${RESET}")

  # 50%到達を warn-context-threshold.py hook(UserPromptSubmit)に伝えるためのマーカー。
  # statusLineはcontext_window.used_percentageを受け取れる唯一のhook種別なので、ここで検知して
  # ファイル経由でUserPromptSubmit hookに引き継ぐ(hookイベント自体はこの値を受け取れない)。
  if [ "${used%.*}" -ge 50 ] && [ -n "$session_id" ]; then
    mkdir -p "$CONTEXT_WARN_DIR"
    touch "${CONTEXT_WARN_DIR}/${session_id}"
  fi
fi

five_s=$(fmt_limit 5h "$five" "$five_reset")
week_s=$(fmt_limit 7d "$week" "$week_reset")
rl="${five_s}${five_s:+${week_s:+ }}${week_s}"
[ -n "$rl" ] && parts+=("⏳ ${rl}")

if [ -n "$cwd" ]; then
  loc="📁 ${C_DIM}$(basename "$cwd")${RESET}"
  branch=$(git -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null \
    || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  [ -n "$branch" ] && loc="${loc} 🌿 ${C_DIM}${branch}${RESET}"
  parts+=("$loc")
fi

output=""
for p in "${parts[@]}"; do
  output="${output:+${output} ${C_DIM}│${RESET} }${p}"
done

printf '%s' "$output"
