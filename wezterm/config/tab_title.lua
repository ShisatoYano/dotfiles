local wezterm = require("wezterm")
local theme = require("config.theme")
local M = {}

-- カスタムタブ名(tab_id -> string)。<leader>,でリネームすると入る
M.custom_title = {}

local ICONS = {
  zoom = wezterm.nerdfonts.md_magnify,
}

-- Tab colors for dark theme 
M.TAB_COLORS_DARK = {
  foreground_inactive = "#f8f8f2",
  background_inactive = "#6272a4", -- Comment(控えめだが視認できる背景)
  foreground_active = "#282a36", -- Background(明るい背景の上の文字色に流用)
  background_active = "#ffd700", -- 目立つ黄色
  background_ssh_active = "#ff5555", -- Red
  foreground_ssh_active = "#f8f8f2", -- Foreground
}

-- Tab colors for light theme
M.TAB_COLORS_LIGHT = {
  foreground_inactive = "#657b83", -- base00
  background_inactive = "#eee8d5", -- base2(控えめだが視認できる背景)
  foreground_active = "#fdf6e3", -- base3(濃い背景の上の文字色に流用)
  background_active = "#b58900", -- yellow(目立つ背景)
  background_ssh_active = "#dc322f", -- red
  foreground_ssh_active = "#fdf6e3", -- base3
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

local function is_ssh_process(process_name, cmdline, user_vars)
  if user_vars.ssh_host and user_vars.ssh_host ~= "" then
    return true, user_vars.ssh_host
  end
  if process_name:find("ssh") or (cmdline and cmdline:find("ssh")) then
    local host = cmdline and cmdline:match("ssh%s+([%w_%-%.]+)")
    return true, host
  end
  return false, nil
end

local function is_claude_process(process_name, pane_title)
  return process_name == "claude" or (pane_title and (pane_title:find("^✳") or pane_title:lower():find("claude")))
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
    local cmdline = pane.foreground_process_name or ""
    local user_vars = pane.user_vars or {}
    local cached_cwd = title_cache[pane_id] or ""

    local is_ssh, ssh_host = is_ssh_process(process_name, cmdline, user_vars)
    if is_ssh and ssh_host then
      ssh_host_cache[pane_id] = ssh_host
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

    -- max_widthはタブ全体の予算なので、caps/アイコン/余白の分を差し引いてから
    -- タイトル本文を切り詰める(そうしないと右端の丸capごと切り詰められてしまう)
    local decoration = " " .. left_circle .. zoom_indicator .. right_circle .. "  "
    local available_width = math.max(max_width - wezterm.column_width(decoration), 1)
    local title = " " .. wezterm.truncate_right(title_text, available_width) .. " "

    return {
      { Background = { Color = edge_background } },
      { Text = " " },
      { Foreground = { Color = edge_foreground } },
      { Text = left_circle },
      { Background = { Color = background } },
      { Foreground = { Color = foreground } },
      { Text = zoom_indicator },
      { Attribute = { Intensity = "Bold" } },
      { Text = title },
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
