local wezterm = require("wezterm")
local M = {}

-- claude/skills/pr-task-planning/scripts/pr-scope.sh の出力と、pr-watchの巡回時刻(heartbeat)を読んで右端に出す
local SCRIPT = wezterm.home_dir .. "/.claude/skills/pr-task-planning/scripts/pr-scope.sh"
local STATE_DIR = (os.getenv("XDG_STATE_HOME") or (wezterm.home_dir .. "/.local/state")) .. "/claude-code/pr-watch/"
local CACHE_DIR = STATE_DIR .. "wezterm/"

M.REFRESH_INTERVAL_S = 300 -- ghの検索を走らせる間隔
M.CACHE_MAX_AGE_S = 1800 -- これより古いキャッシュ(更新に失敗し続けている)は件数を出さない
M.STALE_AFTER_S = 45 * 60 -- 巡回は30分ごとなので、1回抜けたら警告する
M.FORGET_AFTER_S = 24 * 3600 -- これより古い巡回は意図して止めたとみなし、警告しない
local READ_INTERVAL_S = 10

-- タブの黄・Claudeの状態色(緑・青・マゼンタ・赤)と被らないSolarizedのvioletにする
local COUNTS_COLORS = { fg = "#fdf6e3", bg = "#6c71c4" }
local PR_ICON = wezterm.nerdfonts.oct_git_pull_request

local root_by_cwd = {}
local spawned_at = {}
local cache_by_path = {}

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local s = f:read("*a")
  f:close()
  return s
end

local function repo_root(cwd)
  if root_by_cwd[cwd] == nil then
    local ok, out = wezterm.run_child_process({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })
    root_by_cwd[cwd] = ok and out:gsub("%s+$", "") or false
  end
  return root_by_cwd[cwd] or nil
end

local function read_cache(path, now)
  local entry = cache_by_path[path]
  if entry and now - entry.read_at < READ_INTERVAL_S then
    return entry.data
  end
  local data
  local s = read_file(path)
  if s then
    local ok, parsed = pcall(wezterm.json_parse, s)
    data = ok and parsed or nil
  end
  cache_by_path[path] = { read_at = now, data = data }
  return data
end

-- ghは1〜2秒かかりGUIが固まるため、同期実行せずバックグラウンドでキャッシュファイルに書かせる
local function refresh(target, path, now)
  if spawned_at[path] and now - spawned_at[path] < M.REFRESH_INTERVAL_S then
    return
  end
  spawned_at[path] = now
  wezterm.background_child_process({
    "bash",
    "-c",
    'mkdir -p "$1" && bash "$2" list "$3" >"$4.tmp" && mv "$4.tmp" "$4"',
    "pr_status",
    CACHE_DIR,
    SCRIPT,
    target,
    path,
  })
end

local function format_duration(seconds)
  local minutes = math.floor(seconds / 60)
  if minutes < 60 then
    return minutes .. "分"
  end
  local rest = minutes % 60
  return math.floor(minutes / 60) .. "時間" .. (rest > 0 and (rest .. "分") or "")
end

-- 表示する文字列を返す(副作用なし)。counts: 件数の表示、stale: 巡回停止の警告
function M.texts(cache, heartbeat, now)
  local counts, stale
  if cache and now - (cache.generated_at or 0) < M.CACHE_MAX_AGE_S then
    local mine, review, label
    if cache.all then
      mine, review, label = #(cache.mine or {}), #(cache.review_requested or {}), "PR"
    else
      local others = cache.others or {}
      mine, review, label = others.mine or 0, others.review_requested or 0, "他PR"
    end
    local parts = {}
    if mine > 0 then
      table.insert(parts, "自分" .. mine)
    end
    if review > 0 then
      table.insert(parts, "レビュー" .. review)
    end
    if #parts > 0 then
      counts = label .. " " .. table.concat(parts, "・")
    end
  end
  if heartbeat then
    local age = now - heartbeat
    if age >= M.STALE_AFTER_S and age < M.FORGET_AFTER_S then
      stale = "⚠ PR巡回停止 " .. format_duration(age)
    end
  end
  return counts, stale
end

-- 右端に足すwezterm.formatの要素を返す(colorsは巡回停止の警告色に使う)
function M.segments(pane, colors)
  local now = os.time()
  local cwd_url = pane and pane:get_current_working_dir()
  local cwd = cwd_url and cwd_url.file_path
  if not cwd then
    return {}
  end
  local root = repo_root(cwd)
  local target = root or "--all"
  local path = CACHE_DIR .. (root and root:gsub("[^%w._-]", "_") or "all") .. ".json"

  local cache = read_cache(path, now)
  if not cache or now - (cache.generated_at or 0) >= M.REFRESH_INTERVAL_S then
    refresh(target, path, now)
  end
  local heartbeat = cache and cache.key and tonumber(read_file(STATE_DIR .. cache.key .. ".heartbeat") or "")

  local counts, stale = M.texts(cache, heartbeat, now)
  local segments = {}
  if counts then
    table.insert(segments, {
      { Foreground = { Color = COUNTS_COLORS.fg } },
      { Background = { Color = COUNTS_COLORS.bg } },
      { Attribute = { Intensity = "Bold" } },
      { Text = " " .. PR_ICON .. " " .. counts .. " " },
    })
  end
  if stale then
    table.insert(segments, {
      { Foreground = { Color = colors.foreground_ssh_active } },
      { Background = { Color = colors.background_ssh_active } },
      { Attribute = { Intensity = "Bold" } },
      { Text = " " .. stale .. " " },
    })
  end
  return segments
end

return M
