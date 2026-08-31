# nb(メモ管理CLI)やgit commit等で使うエディタをnvimに固定する
export EDITOR=nvim

# ghq管理下のリポジトリ + ~/worktrees配下のworktree(サブモジュール含む)を
# まとめてfzfであいまい検索して移動する。worktree側は[wt]を付けて表示し、
# 普段の癖でgcdを使っても誤ってghq本体側に移動しないようにする
# (~/worktreesが未作成でも、findが何も出力せずghq側だけの一覧になるだけで問題ない)
gcd() {
  local dir
  dir=$(
    { ghq list -p | while read -r p; do printf '%s\t%s\n' "$p" "$p"; done
      find "$HOME/worktrees" -mindepth 1 -name .git 2>/dev/null \
        | xargs -r -n1 dirname \
        | while read -r p; do printf '[wt] %s\t%s\n' "$p" "$p"; done
    } | fzf --delimiter=$'\t' --with-nth=1 | cut -f2
  ) || return
  cd "$dir" || return
}

# bukuのブックマークをfzfであいまい検索してブラウザで開く(Tabキーで複数選択可)
bb() {
  local urls
  urls=$(buku --nostdin -p -f4 --nc | fzf --reverse --multi --preview "buku --nostdin -p {1} --nc" --preview-window=wrap | cut -f2) || return
  [ -n "$urls" ] || return
  while IFS= read -r url; do
    xdg-open "$url" >/dev/null 2>&1 &
  done <<< "$urls"
}

# 毎日の業務開始時に必ず開くページ(bukuで"*_check"タグ = notion_check/attendance_check/
# slack_check/schedule_check/mail_check等を付けたURL)をまとめて新規タブで開く。
# systemdによる自動巡回(tab-check一式)を廃止した代わりに、手動で1コマンド実行する運用にするためのもの
workstart() {
  buku --nostdin -p -f4 --nc 2>/dev/null | awk -F'\t' '
    { n = split($4, tags, /[ ,]+/); for (i = 1; i <= n; i++) if (tags[i] ~ /_check$/) { print $2; break } }
  ' | while IFS= read -r url; do
    [ -z "$url" ] && continue
    xdg-open "$url" >/dev/null 2>&1 &
  done
}

# 指定ディレクトリ以下のファイルをfdfindで再帰的に検索し、fzfで選んだパスを出力する
# (省略時はカレントディレクトリ以下)
ff() {
  local dir="${1:-.}"
  fdfind --type f . "$dir" | fzf
}

# docker composeの短縮形(dc up -d, dc exec <service> bash, dc down等)
alias dc="docker compose"

# mdrollをファイル更新監視付きで起動する(編集中のプレビュー用途)
alias mdw="mdroll --watch"

# 起動中のコンテナをfzfであいまい検索してbashで入る
dexec() {
  local line container
  line=$(docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | fzf --reverse --header="NAMES	IMAGE	STATUS") || return
  container=$(cut -f1 <<< "$line")
  [ -n "$container" ] && docker exec -it "$container" bash
}

# 起動中のコンテナをfzfであいまい検索して停止する(Tabキーで複数選択可)
dstop() {
  docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | fzf --reverse --multi --header="NAMES	IMAGE	STATUS" | cut -f1 | xargs -r docker stop
}

# 自分に関するPRを横断で確認する(自分が出したもの/レビュー依頼が来ているもの)
prs() {
  echo "=== 自分が出したPR ==="
  gh search prs --author @me --state open
  echo
  echo "=== 自分がレビュアーのPR ==="
  gh search prs --review-requested @me --state open
}

# URLがPDFかどうかを判定する(nba/nbsumで共有)
_nb_is_pdf_url() {
  local url="$1"
  local content_type
  content_type=$(curl -sIL --max-time 10 "$url" 2>/dev/null | tr -d '\r' | grep -i '^content-type:' | tail -1)
  if echo "$content_type" | grep -qi 'application/pdf'; then
    return 0
  fi
  [[ "$url" =~ \.pdf($|\?) ]]
}

# URLを渡すとタイトルを自動取得してnbにメモを作成する(nba <url> / タイトルを手動指定するならnba <title> <url>)
# PDF(論文など)の場合はpdfinfoのメタデータからタイトルを取る(取れなければURLのファイル名を使う)
# ノートは<タイトル>/<タイトル>.mdというフォルダ配置で作成する(nbsumで図を追加した際に同じフォルダにまとめるため)
nba() {
  if [ $# -lt 1 ]; then
    echo "Usage: nba <url>           # タイトルを自動取得"
    echo "       nba <title> <url>   # タイトルを手動指定"
    return 1
  fi

  local title="" url=""
  if [ $# -eq 1 ]; then
    url="$1"
    echo "Fetching title from: $url"

    if _nb_is_pdf_url "$url"; then
      local tmp_pdf
      tmp_pdf=$(mktemp --suffix=.pdf)
      curl -sL --max-redirs 3 --max-time 20 -o "$tmp_pdf" "$url"
      title=$(pdfinfo "$tmp_pdf" 2>/dev/null | grep "^Title:" | sed 's/^Title:[[:space:]]*//')
      rm -f "$tmp_pdf"
      if [ -z "$title" ]; then
        title=$(basename "$url" .pdf | sed 's/[-_]/ /g')
      fi
    else
      title=$(curl -sL --max-redirs 3 --max-time 5 --compressed "$url" |
              head -c 512 |
              perl -0777 -ne 'print $1 if /<title[^>]*>([^<]+)<\/title>/i')
      title=$(echo "$title" | perl -pe 's/^\s+|\s+$//g; s/\s+/ /g')
    fi

    if [ -z "$title" ]; then
      echo "Error: Could not fetch title from URL"
      return 1
    fi
    echo "Title: $title"
  else
    title="$1"
    url="$2"
  fi

  local content="# ${title}

参照: [${title}](${url})"

  nb add --filename "${title}/${title}.md" --content "$content"
  echo "Note created: [${title}](${url})"
}

# nbのメモをfzfであいまい検索し、プレビューを見ながら選んでnvimで編集する
# note_id(数字)ではなく絶対パスで選択・オープンするので、フォルダ配下のノートも問題なく扱える
nbq() {
  if [ -z "$1" ]; then
    echo "Usage: nbq <search query>"
    return 1
  fi

  local query="$*"
  local results
  results=$(nb search "$query" --path --no-color 2>/dev/null | grep -v '/\.index$')

  if [ -z "$results" ]; then
    echo "No results found for: $query"
    return 1
  fi

  export _NBQ_QUERY="$query"

  local selected
  selected=$(echo "$results" | fzf \
    --preview 'echo "=== $(basename {}) ==="
               echo ""
               grep -i --color=always -C 2 "$_NBQ_QUERY" {} | head -30' \
    --preview-window=right:60%:wrap \
    --header "Search: $query")

  unset _NBQ_QUERY

  [ -n "$selected" ] && nb edit "$selected"
}

# nbのメモをfzfで選び、mdroll(--watch)でMarkdownプレビューする(パス入力不要)
# フォルダ配下のノートも拾えるよう、notebookディレクトリ配下を再帰的にfindする
nbmd() {
  local notebook_dir selected
  notebook_dir=$(nb notebooks current --path) || return
  selected=$(find "$notebook_dir" -type f -name '*.md' | fzf \
    --preview 'cat {}' \
    --preview-window=right:60%:wrap) || return
  [ -n "$selected" ] || return
  mdroll --watch "$selected"
}

# nba等で作成したノート内のURLをClaudeに要約させ、本文に追記する(nbsum <note id>)
nbsum() {
  if [ -z "$1" ]; then
    echo "Usage: nbsum <note id>"
    return 1
  fi

  local note_id="$1"
  local path note_dir url
  path=$(nb show "$note_id" --path) || return 1
  note_dir=$(dirname "$path")
  url=$(grep -oE 'https?://[^)]+' "$path" | head -1)

  if [ -z "$url" ]; then
    echo "Error: No URL found in note $note_id"
    return 1
  fi

  echo "Fetching: $url"
  local page_text
  local -a image_files=()
  if _nb_is_pdf_url "$url"; then
    local tmp_pdf tmp_img_dir
    tmp_pdf=$(mktemp --suffix=.pdf)
    curl -sL --max-redirs 3 --max-time 30 -o "$tmp_pdf" "$url"
    page_text=$(pdftotext -layout "$tmp_pdf" - 2>/dev/null | perl -pe 's/\s+/ /g' | head -c 20000)

    # 埋め込み画像のうち透過マスク(smask)を除いた本物の図だけをノートと同じフォルダに保存する
    tmp_img_dir=$(mktemp -d)
    pdfimages -png "$tmp_pdf" "$tmp_img_dir/fig" 2>/dev/null
    local num fig_index=1
    while IFS= read -r num; do
      local src
      src=$(printf '%s/fig-%03d.png' "$tmp_img_dir" "$num")
      if [ -f "$src" ]; then
        cp "$src" "${note_dir}/fig${fig_index}.png"
        image_files+=("fig${fig_index}.png")
        fig_index=$((fig_index + 1))
      fi
    done < <(pdfimages -list "$tmp_pdf" 2>/dev/null | tail -n +3 | awk '$3 == "image" {print $2}')
    rm -rf "$tmp_img_dir"

    rm -f "$tmp_pdf"
  else
    page_text=$(curl -sL --max-redirs 3 --max-time 10 --compressed "$url" |
      perl -0777 -pe 's/<script.*?<\/script>//gis; s/<style.*?<\/style>//gis; s/<[^>]+>/ /g; s/&nbsp;/ /g; s/\s+/ /g' |
      head -c 8000)
  fi

  if [ -z "$page_text" ]; then
    echo "Error: Could not fetch page content"
    return 1
  fi

  echo "Summarizing with claude..."
  local summary
  summary=$(echo "$page_text" | claude -p "以下はウェブページの本文をテキスト抽出したものです。日本語で、下記の2見出し構成のMarkdownで出力してください(前置きや締めの言葉は不要です)。

## 要約
箇条書き3〜5行の簡潔な要約

## 詳細
見出しや箇条書きを使った、もう少し詳しい内容のまとめ")

  if [ -z "$summary" ]; then
    echo "Error: Failed to get summary from claude"
    return 1
  fi

  printf '\n%s\n' "$summary" >> "$path"

  if [ "${#image_files[@]}" -gt 0 ]; then
    {
      echo ""
      echo "## 図"
      echo ""
      for f in "${image_files[@]}"; do
        echo "![${f}](${f})"
      done
    } >> "$path"
    echo "Imported ${#image_files[@]} image(s)"
  fi

  (cd "$note_dir" && git add -A && git commit -q -m "Summarize: $(basename "$path")")
  echo "Note updated: $path"
}

# git pushブロック用フック(claude/hooks/block-git-push.py)のトグルを操作する
alias gpushctl="$HOME/dotfiles/scripts/claude-git-push-ctl.sh"

# Neovimプラグイン開発でCIと同じLuaチェック(stylua --check + luacheck)をカレントディレクトリで実行する
# (luacheckは.luacheckrcをカレントディレクトリから探すため、対象リポジトリのルートで実行すること)
luaci() {
  local status=0
  echo "=== stylua --check ==="
  stylua --check . || status=1
  echo "=== luacheck ==="
  luacheck lua || status=1
  return "$status"
}
