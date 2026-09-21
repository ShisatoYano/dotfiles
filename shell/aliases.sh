# nb(メモ管理CLI)やgit commit等で使うエディタをnvimに固定する
export EDITOR=nvim

# ghq管理下のリポジトリをfzfであいまい検索して移動する
gcd() {
  local dir
  dir=$(ghq list -p | fzf) || return
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
workstart() {
  buku --nostdin -p -f4 --nc 2>/dev/null | awk -F'\t' '
    { n = split($4, tags, /[ ,]+/); for (i = 1; i <= n; i++) if (tags[i] ~ /_check$/) { print $2; break } }
  ' | while IFS= read -r url; do
    [ -z "$url" ] && continue
    xdg-open "$url" >/dev/null 2>&1 &
  done
}

# 標準入力からタブ(id\ttitle\turl)を受け取り、bukuに保存してから閉じる共通処理
# 第1引数にsummarizeを渡すと、閉じる前にページ内容の要約をnbのメモとして残す(tabnote)
# 比較はURLのみで行う(タブタイトルは未読件数などで頻繁に変わり、
# 保存済みブックマークのタイトルとは一致しないことが多いため)
_tabarchive_process() {
  local summarize="${1:-}"
  local existing
  existing=$(buku --nostdin -p -f1 --nc | cut -f2)
  while IFS=$'\t' read -r id title url; do
    if grep -Fxq "$url" <<< "$existing"; then
      echo "skip (既存): $title"
    else
      buku --nostdin -a "$url" tab-archive
    fi
    # 要約まで通らなかったタブは閉じずに残し、取りこぼしに気づけるようにする
    if [ "$summarize" = "summarize" ] && ! _tabnote_summarize "$title" "$url"; then
      echo "skip (要約に失敗、タブは開いたまま): $title"
      continue
    fi
    tabctl close "$id"
  done
}

# タブのタイトルとURLからnbのメモを作り、ページ内容の要約(nbsum)まで済ませる
# メモは作業中のカレントノートブックを汚さないよう、専用ノートブック(bukuのタグ名と揃える)に入れる
_tabnote_summarize() {
  local path
  echo "Note: $1"
  path=$(_nb_create_note "$1" "$2" tab-archive) || return 1
  nbsum "$path"
}

# 選択したタブをbukuに保存してから閉じる(Tabキーで複数選択可)
tabarchive() {
  tabctl list | fzf --reverse --multi --delimiter="\t" --with-nth=2,3 | _tabarchive_process
}

# 開いている全タブをbukuに保存してから閉じる
tabarchive-all() {
  tabctl list | _tabarchive_process
}

# 選択したタブをbukuに保存し、ページ内容をClaudeで要約したメモをnbに残してから閉じる
# (Tabキーで複数選択可。要約はタブごとにclaude -pを呼ぶので、タブ数に比例して時間がかかる)
tabnote() {
  tabctl list | fzf --reverse --multi --delimiter="\t" --with-nth=2,3 | _tabarchive_process summarize
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

# prsの内容をgh dashでインタラクティブに見る。
# gh dashはgitリポジトリ内で起動するとそのリポジトリにのみ絞り込むため、
# リポジトリ外(~)で起動してリポジトリ横断のグローバル検索にする
prsd() {
  (cd ~ && gh dash)
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

  local path
  path=$(_nb_create_note "$title" "$url") || return 1
  echo "Note created: [$(basename "$path" .md)](${url})"
}

# タイトルはノートのフォルダ名とファイル名にそのまま使われるため、
# パス区切りを潰し、タブタイトル特有の未読件数の接頭辞(「(9+) 」等)を落とす
# (GitHubの「ユーザー名/リポジトリ名: ...」のようなタイトルが入れ子フォルダになるのを防ぐ)
_nb_sanitize_title() {
  printf '%s' "$1" | perl -pe 's{^\(\d+\+?\)\s*}{}; s{[/\\]}{-}g; s/^\s+|\s+$//g; s/\s+/ /g'
}

# 指定したノートブックが無ければ作る(nb notebooks addは既存でも終了コード0を返すので、
# 「Already exists」を毎回出さないよう先に存在を確かめる)
_nb_ensure_notebook() {
  local name="$1" path
  while IFS= read -r path; do
    [ "$(basename "$path")" = "$name" ] && return 0
  done < <(nb notebooks --paths)
  nb notebooks add "$name" >&2
}

# タイトルとURLからノートを作り、作成したノートの絶対パスを返す(nba/tabnoteで共有)
# 第3引数でノートブックを指定できる(省略時はカレントノートブック)
_nb_create_note() {
  local title url notebook prefix content
  title=$(_nb_sanitize_title "$1")
  url="$2"
  notebook="${3:-}"
  [ -n "$title" ] || return 1

  prefix=""
  if [ -n "$notebook" ]; then
    _nb_ensure_notebook "$notebook" || return 1
    prefix="${notebook}:" # nbはサブコマンド側に付けた接頭辞で保存先を切り替える(カレントは変えない)
  fi

  content="# ${title}

参照: [${title}](${url})"

  # stdoutはパスを返すのに使うので、nb addが出すノートIDの表示はstderrへ逃がす。
  # またnb addはパイプされた標準入力を本文として読むため、tabnoteのように
  # タブ一覧を流し込むループの中から呼ばれても残りを食わないよう/dev/nullをつなぐ
  nb "${prefix}add" --filename "${title}/${title}.md" --content "$content" >&2 < /dev/null || return 1
  nb show "${prefix}${title}/${title}.md" --path
}

# 全notebookのノートをrgで検索させ、選ばれたヒット行のノートをnbの識別子
# (<notebook名>:<notebook内の相対パス>)として返す(nbq/nbmdで共有)
# 絶対パスではなく識別子で返すのは、nbが絶対パスをカレントnotebook内でしか解決できず、
# 他のnotebook(tabnoteが使うtab-archive等)のノートがnb editで開けないため
# 第1引数はEnterを押したら何が起きるかのヘッダー表示、残りはfzfの初期クエリ
# 入力のたびrgを走らせ直す(--disabled + reload)。fzfに本文全体を食わせてあいまい検索させると
# 飛び飛びの一致で無関係なノートが大量に並ぶため、絞り込みはrgに任せている
# nb notebooks addで追加したnotebookは~/.nb配下がシンボリックリンクになるため--followで辿る
# rgは~/.nb上で相対パスとして走らせ、一覧を「notebook名/ノート名:行番号」の短い表示に保つ
_nb_pick_note() {
  local action="$1"
  shift

  local nb_root
  nb_root=$(nb notebooks --paths | head -1)
  if [ -z "$nb_root" ]; then
    echo "Error: No notebooks found" >&2
    return 1
  fi
  nb_root=$(dirname "$nb_root")

  local -a books=()
  local path
  while IFS= read -r path; do books+=("$(basename "$path")"); done < <(nb notebooks --paths)

  # 本文検索だけだと、ファイル名が本文に出てこないノート(連番ファイル名等)に辿り着けない。
  # ファイル名一致を:1:の行として先に並べ、本文ヒットと同じ「パス:行番号:内容」の形に揃える
  local books_q rg_cmd
  books_q=$(printf '%q ' "${books[@]}")
  rg_cmd="{ rg --follow --files --glob '*.md' $books_q | rg --color=always --smart-case -- {q} | sed 's/\$/:1:/';
             rg --follow --line-number --no-heading --color=always --smart-case --glob '*.md' -- {q} $books_q; }"

  local selected
  # ヒットなしでrgが1を返してもfzfを終了させないよう|| trueで受ける
  selected=$(cd "$nb_root" && fzf --ansi --disabled --query="$*" \
    --bind "start:reload:$rg_cmd || true" \
    --bind "change:reload:$rg_cmd || true" \
    --delimiter=: \
    --preview 'cat {1}' \
    --preview-window='right:60%:wrap:+{2}-5' \
    --header "ripgrepで本文+ファイル名を検索 / Enter: $action") || return
  [ -n "$selected" ] || return 1

  # rgの出力は「notebook名/ノート名:行番号:内容」なので、先頭の/を:に替えればnbの識別子になる
  printf '%s' "$selected" | cut -d: -f1 | sed 's|/|:|'
}

# nbのメモを検索し、ヒットしたノートをnvimで編集する(nbq [初期クエリ])
# nb editは行番号を取れないので、ヒット行の位置はプレビュー側(+{2}-5)で見せるに留める
nbq() {
  local id
  id=$(_nb_pick_note "nvimで編集" "$@") || return
  [ -n "$id" ] && nb edit "$id"
}

# nbのメモを検索し、ヒットしたノートをmdroll(--watch)でMarkdownプレビューする(nbmd [初期クエリ])
nbmd() {
  local id path
  id=$(_nb_pick_note "mdrollでプレビュー" "$@") || return
  [ -n "$id" ] || return
  # mdrollはnbの識別子を解釈しないので、実ファイルのパスに直してから渡す
  path=$(nb show "$id" --path) || return 1
  mdroll --watch "$path"
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
