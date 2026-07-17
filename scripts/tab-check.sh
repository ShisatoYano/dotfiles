#!/usr/bin/env bash
# 引数で指定したbukuタグが付いたURLを確認し、
# 既に開いていればそのタブをアクティブにし(ウィンドウのフォーカスは奪わない)、
# 無ければ新規タブで開く。systemdユーザータイマー(*.timer)から「tab-check.sh <タグ名>」の形で
# 定期実行する想定(notion-check.service/attendance-check.service等、タグごとにサービスを分ける)。
#
# buku組み込みの-t/--stagによるタグ絞り込みが環境によっては効かない(全件返る)ことが
# あったため、-p -f4で全件取得してからタグ列を自前でフィルタしている。
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "使い方: $(basename "$0") <bukuタグ名>" >&2
  exit 1
fi
TAG="$1"

tabs=$(tabctl list 2>/dev/null || true)

buku --nostdin -p -f4 --nc 2>/dev/null | awk -F'\t' -v tag="$TAG" '
  { n = split($4, tags, /[ ,]+/); for (i = 1; i <= n; i++) if (tags[i] == tag) { print $2; break } }
' | while IFS= read -r url; do
  [ -z "$url" ] && continue
  # NotionはSPAでビューID等がURLの?以降に付いたり変わったりするため、
  # クエリ/フラグメントを除いたページパス部分だけで一致を判定する
  id=$(printf '%s\n' "$tabs" | awk -F'\t' -v u="$url" '
    BEGIN { split(u, a, /[?#]/); base = a[1] }
    { split($3, b, /[?#]/); if (b[1] == base) { print $1; exit } }
  ')
  if [ -n "$id" ]; then
    tabctl activate "$id" >/dev/null 2>&1 || true
  else
    tabctl open "$url" >/dev/null 2>&1 || true
  fi
done
