local wezterm = require("wezterm")
local theme = require("config.theme")
local M = {}

-- カスタムタブ名(tab_id -> string)。<leader>,でリネームすると入る
M.custom_title = {}

local ICONS = {
  zoom = wezterm.nerdfonts.md_magnify,
  -- ●○(U+25CF/25CB)は東アジアの曖昧幅で、日本語フォントだと2桁に描かれ隣と重なる
  -- 黄背景では深い色同士の色相が見分けにくいため、状態は形でも区別する
  claude_status = {
    busy = wezterm.nerdfonts.md_checkbox_blank_circle,
    idle = wezterm.nerdfonts.md_checkbox_blank_circle_outline,
    error = wezterm.nerdfonts.md_alert_circle,
  },
}

-- Claude Codeの状態ごとの丸の色。黄は黄背景のアクティブタブに埋もれるため使わない
-- 明るいアクセント色は黄背景・明るい背景だとコントラスト比が約1:1で見えないため、そこでは濃い色を使う
local CLAUDE_STATUS_BRIGHT = {
  busy = "#859900", -- green
  idle = "#268bd2", -- blue
  error = "#dc322f", -- red
}
local CLAUDE_STATUS_DEEP = {
  busy = "#185200", -- deep green
  idle = "#08348c", -- deep blue
  error = "#8c0d0a", -- deep red
}

-- claude/hooks/wezterm-tab-state.shがStopFailureで書き、次の入力で消す
local CLAUDE_STATE_DIR = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/claude-tab-state/"

-- Tab colors for dark theme 
M.TAB_COLORS_DARK = {
  foreground_inactive = "#839395", -- base0
  background_inactive = "#002c38", -- base02(控えめだが視認できる背景)
  foreground_active = "#001419", -- base03(明るい背景の上の文字色に流用)
  background_active = "#b28500", -- yellow(目立つ背景)
  background_ssh_active = "#db302d", -- red
  foreground_ssh_active = "#fdf6e3", -- base3
  claude_status_active = CLAUDE_STATUS_DEEP,
  claude_status_inactive = CLAUDE_STATUS_BRIGHT, -- 濃い背景なので明るい色
}

-- Tab colors for light theme
M.TAB_COLORS_LIGHT = {
  foreground_inactive = "#657b83", -- base00
  background_inactive = "#eee8d5", -- base2(控えめだが視認できる背景)
  foreground_active = "#fdf6e3", -- base3(濃い背景の上の文字色に流用)
  background_active = "#b58900", -- yellow(目立つ背景)
  background_ssh_active = "#dc322f", -- red
  foreground_ssh_active = "#fdf6e3", -- base3
  claude_status_active = CLAUDE_STATUS_DEEP,
  claude_status_inactive = CLAUDE_STATUS_DEEP,
}

-- Starshipプロンプトの左右の丸caps([](fg:accent5)[...]の形)と同じグリフに揃える
local DECORATIONS = {
  left_circle = "\u{e0ba}",
  right_circle = "\u{e0bc}",
}

-- Function to select color theme for current tab
function M.current_tab_colors(config)
  if config.color_scheme == theme.light_scheme then
    return M.TAB_COLORS_LIGHT
  end
  return M.TAB_COLORS_DARK
end

-- Function to get tab colors depend on it is active, ssh
local function get_tab_colors(colors, is_active, is_ssh)
  if is_active and is_ssh then
    return colors.background_ssh_active, colors.foreground_ssh_active
  elseif is_active then
    return colors.background_active, colors.foreground_active
  end
  return colors.background_inactive, colors.foreground_inactive
end

local function basename(path)
  return string.gsub(path or "", "(.*[/\\])(.*)", "%2")
end

-- タイトルに紛れ込むエスケープシーケンスや制御文字を除去する
-- (Claude Code等がOSCでタイトルを設定する際、まれに表示が崩れることがあるため)
local function sanitize_title(s)
  if not s or s == "" then
    return s
  end
  s = s:gsub("\27%][^\7\27]*\7", "")
  s = s:gsub("\27%][^\27]*\27\\", "")
  s = s:gsub("\27%[[%d;]*%a", "")
  s = s:gsub("[%z\1-\8\11\12\14-\31\127]", "")
  return s
end

local function is_ssh_process(process_name, user_vars)
  if user_vars.ssh_host and user_vars.ssh_host ~= "" then
    return true, user_vars.ssh_host
  end
  return process_name == "ssh", nil
end

-- 値を取るsshオプション(man ssh)。これを飛ばさないと`-p 22`の22を接続先と誤認する
local SSH_OPTS_WITH_ARG = "BbcDEeFIiJLlmOoPpQRSWw"

-- ssh起動時のargvから接続先を`user@host`の形で取り出す
local function ssh_destination(argv)
  local user, dest
  local i = 2
  while i <= #argv and not dest do
    local arg = argv[i]
    if arg == "--" then
      dest = argv[i + 1]
    elseif arg:sub(1, 1) == "-" and #arg > 1 then
      -- `-vp22`のように複数オプションや値が連結される場合がある
      for j = 2, #arg do
        local opt = arg:sub(j, j)
        if SSH_OPTS_WITH_ARG:find(opt, 1, true) then
          local value = arg:sub(j + 1)
          if value == "" then
            i = i + 1
            value = argv[i]
          end
          if opt == "l" then
            user = value
          end
          break
        end
      end
    else
      dest = arg
    end
    i = i + 1
  end

  if not dest then
    return nil
  end
  dest = dest:gsub("^ssh://", ""):gsub(":%d+$", "")
  if user and not dest:find("@") then
    dest = user .. "@" .. dest
  end
  return dest
end

local function ssh_label(pane_id)
  local mux_pane = wezterm.mux.get_pane(pane_id)
  local info = mux_pane and mux_pane:get_foreground_process_info()
  return info and info.argv and ssh_destination(info.argv)
end

local function is_claude_process(process_name, pane_title)
  -- native版の実行ファイル名はclaude.exe
  return process_name:find("^claude") or (pane_title and (pane_title:find("^✳") or pane_title:lower():find("claude")))
end

-- Claude Codeはタイトル先頭に状態記号を付ける(入力待ち: ✳ / 処理中: ◑等のスピナー)
local function parse_claude_title(title)
  local mark, heading = title:match("^(%S+)%s+(.+)$")
  if not mark or utf8.len(mark) ~= 1 or mark:byte(1) < 0x80 then
    return false, nil
  end
  if heading == "Claude Code" then
    heading = nil
  end
  return mark ~= "✳", heading
end

local function has_claude_error(pane_id)
  local f = io.open(CLAUDE_STATE_DIR .. pane_id, "r")
  if not f then
    return false
  end
  f:close()
  return true
end

-- タブ内のいずれかのペインでClaude Codeが動いていれば、その状態(busy/idle/error)と見出しを返す
local function find_claude(panes)
  for _, p in ipairs(panes) do
    local title = sanitize_title(p.title or "")
    if is_claude_process(basename(p.foreground_process_name), title) then
      local busy, heading = parse_claude_title(title)
      local state = busy and "busy" or (has_claude_error(p.pane_id) and "error" or "idle")
      return { state = state, heading = heading }
    end
  end
  return nil
end

local function truncate_with_ellipsis(s, width)
  if wezterm.column_width(s) <= width then
    return s
  end
  return wezterm.truncate_right(s, width - 1) .. "…"
end

-- 本体の取り分(割合)。見出しが短ければ、余った幅は本体に回す
local MAIN_SHARE = 0.4

-- 本体(プロジェクト名等)と見出しの両方が読めるよう、幅を按分して切り詰める
local function fit_body(main, heading, width)
  local sep = ": "
  local room = width - wezterm.column_width(sep)
  -- 両方を数文字ずつ出す余地もなければ本体だけにする
  if not heading or room < 8 then
    return truncate_with_ellipsis(main, width)
  end

  local main_width = wezterm.column_width(main)
  local heading_width = wezterm.column_width(heading)
  if main_width + heading_width <= room then
    return main .. sep .. heading
  end

  local main_cap = math.max(math.floor(room * MAIN_SHARE), room - heading_width)
  local main_text = truncate_with_ellipsis(main, main_cap)
  local heading_text = truncate_with_ellipsis(heading, room - wezterm.column_width(main_text))
  return main_text .. sep .. heading_text
end

local function extract_project_name(cwd)
  if not cwd then
    return "-"
  end

  local home = os.getenv("HOME")
  if home and cwd:find("^" .. home) then
    cwd = cwd:gsub("^" .. home, "~")
  end

  -- ghq等のgithub.com/<user>/<repo>形式のパスならリポジトリ名を使う
  local _, project = cwd:match(".*github%.com/([^/]+)/([^/]+)")
  if project then
    return project
  end

  -- 最後のディレクトリ名
  cwd = cwd:gsub("/$", "")
  return cwd:match("([^/]+)$") or cwd
end

local function has_zoomed_pane(panes)
  for _, pane_info in ipairs(panes) do
    if pane_info.is_zoomed then
      return true
    end
  end
  return false
end

-- ShowTabNavigator(組み込み)はプロセス名しか出せないため、
-- プロジェクト名が分かる自作のタブ選択ピッカーを用意する
-- (setup()実行前に他モジュールから参照されても良いようトップレベルで定義する)
function M.tab_picker()
  return wezterm.action_callback(function(window, pane)
    local mux_window = window:mux_window()
    local tabs = mux_window:tabs()
    local choices = {}

    for index, tab in ipairs(tabs) do
      local active_pane = tab:active_pane()
      local tab_id = tab:tab_id()
      local custom = M.custom_title[tab_id]

      local label
      if custom then
        label = custom
      else
        local ok, cwd_url = pcall(function()
          return active_pane:get_current_working_dir()
        end)
        local cwd = ok and cwd_url and cwd_url.file_path or nil
        label = extract_project_name(cwd)
      end

      -- タブ内のどのペインがアクティブでも、Claude Codeが動いているペインがあれば
      -- 見出し(セッション内容の要約)を優先して表示する(そのタブの作業目的が分かるように)
      local detail = nil
      for _, p in ipairs(tab:panes()) do
        local p_process = basename(p:get_foreground_process_name() or "")
        local p_title = sanitize_title(p:get_title() or "")
        if is_claude_process(p_process, p_title) and p_title ~= "" then
          detail = p_title
          break
        end
      end

      if not detail then
        detail = basename(active_pane:get_foreground_process_name() or "")
      end
      if detail == "" then
        detail = "?"
      end

      table.insert(choices, {
        id = tostring(tab_id),
        label = string.format("%d: %s  (%s)", index, label, detail),
      })
    end

    window:perform_action(
      wezterm.action.InputSelector({
        title = "タブを選択",
        fuzzy = true,
        choices = choices,
        action = wezterm.action_callback(function(_, _, id, _)
          if not id then
            return
          end
          for _, tab in ipairs(mux_window:tabs()) do
            if tostring(tab:tab_id()) == id then
              tab:activate()
              break
            end
          end
        end),
      }),
      pane
    )
  end)
end

function M.setup(config)
  local title_cache = {}
  local raw_cwd_cache = {}
  local ssh_host_cache = {}

  -- cwdキャッシュ更新(重い処理を毎描画走らせないため)
  wezterm.on("update-status", function(_, pane)
    local pane_id = pane:pane_id()
    local user_vars = pane.user_vars or {}

    if not (user_vars.ssh_host and user_vars.ssh_host ~= "") then
      local cwd_url = pane:get_current_working_dir()
      local cwd = cwd_url and cwd_url.file_path
      if cwd ~= raw_cwd_cache[pane_id] then
        raw_cwd_cache[pane_id] = cwd
        title_cache[pane_id] = extract_project_name(cwd)
      end
    end
  end)

  wezterm.on("format-tab-title", function(tab, _, _, config, _, max_width)
    local pane = tab.active_pane
    local pane_id = pane.pane_id
    local process_name = basename(pane.foreground_process_name)
    local user_vars = pane.user_vars or {}
    local cached_cwd = title_cache[pane_id] or ""

    local is_ssh, ssh_host = is_ssh_process(process_name, user_vars)
    if is_ssh and not ssh_host_cache[pane_id] then
      -- argv取得は/procを読むため、接続ごとに1回だけ行う
      ssh_host_cache[pane_id] = ssh_host or ssh_label(pane_id)
    elseif not is_ssh then
      ssh_host_cache[pane_id] = nil
    end

    local colors = M.current_tab_colors(config)
    local background, foreground = get_tab_colors(colors, tab.is_active, is_ssh)
    local edge_background = "transparent"
    local edge_foreground = background

    local title_text
    local custom = M.custom_title[tab.tab_id] or (tab.tab_title ~= "" and sanitize_title(tab.tab_title) or nil)
    if custom then
      title_text = custom
    elseif is_ssh then
      title_text = ssh_host_cache[pane_id] or "ssh"
    else
      -- update-statusのキャッシュを待たず、current_working_dirから同期的に算出する
      -- (切り替え直後の一瞬キャッシュが無い状態で表示が空になるのを防ぐ)
      local ok, cwd_url = pcall(function()
        return pane.current_working_dir
      end)
      local live_cwd = ok and cwd_url and cwd_url.file_path or nil
      if live_cwd then
        title_text = extract_project_name(live_cwd)
      elseif title_cache[pane_id] and title_cache[pane_id] ~= "" then
        title_text = title_cache[pane_id]
      elseif cached_cwd ~= "" then
        title_text = cached_cwd
      else
        title_text = "-"
      end
    end

    local zoom_indicator = has_zoomed_pane(tab.panes) and (ICONS.zoom .. " ") or ""
    local left_circle = DECORATIONS.left_circle
    local right_circle = DECORATIONS.right_circle

    local claude = find_claude(tab.panes)
    local index = tostring(tab.tab_index + 1) .. " "
    local status_icon = claude and (ICONS.claude_status[claude.state] .. " ") or ""
    local status_palette = tab.is_active and colors.claude_status_active or colors.claude_status_inactive
    local status_color = claude and status_palette[claude.state] or foreground
    local head = index .. status_icon .. zoom_indicator

    -- max_widthはタブ全体の予算なので、caps/番号/アイコン/余白の分を差し引いてから
    -- タイトル本文を切り詰める(そうしないと右端の丸capごと切り詰められてしまう)
    local decoration = " " .. left_circle .. head .. right_circle .. "  "
    local available_width = math.max(max_width - wezterm.column_width(decoration), 1)
    local body = fit_body(title_text, claude and claude.heading, available_width)

    return {
      { Background = { Color = edge_background } },
      { Text = " " },
      { Foreground = { Color = edge_foreground } },
      { Text = left_circle },
      { Background = { Color = background } },
      { Foreground = { Color = foreground } },
      { Text = " " .. index },
      { Foreground = { Color = status_color } },
      { Text = status_icon },
      { Foreground = { Color = foreground } },
      { Text = zoom_indicator },
      { Attribute = { Intensity = "Bold" } },
      { Text = body .. " " },
      { Attribute = { Intensity = "Normal" } },
      { Background = { Color = edge_background } },
      { Foreground = { Color = edge_foreground } },
      { Text = right_circle },
    }
  end)

  -- タブ名を手動でリネーム(空にするとリセット)
  config.keys = config.keys or {}
  table.insert(config.keys, {
    key = ",",
    mods = "LEADER",
    action = wezterm.action_callback(function(window, pane)
      local tab = pane:tab()
      local tab_id = tab:tab_id()
      local current = M.custom_title[tab_id] or ""
      window:perform_action(
        wezterm.action.PromptInputLine({
          description = "タブ名を変更(空でリセット):",
          initial_value = current,
          action = wezterm.action_callback(function(_, inner_pane, line)
            if line == nil then
              return
            end
            local t = inner_pane:tab()
            if line == "" then
              M.custom_title[t:tab_id()] = nil
            else
              M.custom_title[t:tab_id()] = line
            end
          end),
        }),
        pane
      )
    end),
  })
end

return M
