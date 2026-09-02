#!/usr/bin/env bash
# gh dashのカスタムキーバインドから呼ばれ、PR本文(Overview)に添付された画像/動画を
# ブラウザを開かずにターミナル上で表示する。
# 使い方: gh-pr-media.sh <owner/repo> <PR番号>
set -euo pipefail

repo="$1"
number="$2"

body=$(gh pr view "$number" --repo "$repo" --json body -q .body)

# markdown画像記法・HTMLのimg/video/sourceタグ・GitHub添付の裸URLをまとめて抽出
mapfile -t urls < <(
  {
    grep -oP '!\[[^]]*\]\(\K[^)]+' <<< "$body" || true
    grep -oP '<(img|video|source)\b[^>]*\bsrc="\K[^"]+' <<< "$body" || true
    grep -oP 'https://(github\.com/user-attachments/assets|user-images\.githubusercontent\.com|private-user-images\.githubusercontent\.com)/[A-Za-z0-9/_.-]+' <<< "$body" || true
  } | sort -u
)

if [ ${#urls[@]} -eq 0 ]; then
  echo "添付画像・動画は見つかりませんでした"
  read -r -n 1 -s -p "(Enterで閉じます)"
  exit 0
fi

while true; do
  url=$(printf '%s\n' "${urls[@]}" | fzf --prompt="表示する添付を選択(Escで終了)> ") || break
  [ -n "$url" ] || break

  tmp=$(mktemp)
  curl -sL -H "Authorization: Bearer $(gh auth token 2>/dev/null || true)" -o "$tmp" "$url"

  # GitHubの添付URLはS3の署名付きURLにリダイレクトされ、署名がGET専用のため
  # HEADリクエストでは検証エラーになる。ダウンロード済みの内容から判定する
  content_type=$(file --mime-type -b "$tmp")

  case "$content_type" in
    image/*)
      wezterm imgcat "$tmp"
      read -r -n 1 -s -p "(Enterで一覧に戻ります)"
      ;;
    video/*)
      mpv "$tmp"
      ;;
    *)
      echo "非対応の形式(${content_type:-unknown})です。ブラウザで開きます。"
      xdg-open "$url" >/dev/null 2>&1 &
      read -r -n 1 -s -p "(Enterで一覧に戻ります)"
      ;;
  esac
  rm -f "$tmp"
done
