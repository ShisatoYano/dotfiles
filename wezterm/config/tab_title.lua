local wezterm = require("wezterm")
local M = {}

-- カスタムタブ名(tab_id -> string)。<leader>,でリネームすると入る
M.custom_title = {}

local ICONS = {
  docker = wezterm.nerdfonts.md_docker,
  neovim = wezterm.nerdfonts.linux_neovim,
  ssh = wezterm.nerdfonts.md_lan,
  claude = "✳",
  fallback = wezterm.nerdfonts.dev_terminal,
  zoom = wezterm.nerdfonts.md_magnify,
}

local ICON_COLORS = {
  docker = "#4169e1",
  neovim = "#57A143",
  ssh = "#ff6188",
  claude = "#D97757", -- Claude Codeのブランドカラー
}

-- Monokai Pro (Pro)のパレットに合わせた配色
local TAB_COLORS = {
  foreground_inactive = "#939293",
  background_inactive = "none",
  foreground_active = "#2d2a2e",
  background_active = "#78dce8",
  background_ssh_active = "#ff6188",
  foreground_ssh_active = "#fcfcfa",
}

local DECORATIONS = {
  left_circle = wezterm.nerdfonts.ple_left_half_circle_thick,
  right_circle = wezterm.nerdfonts.ple_right_half_circle_thick,
}

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

local function get_icon_and_color(process_name, pane_title, cwd, is_ssh, is_claude)
  if is_ssh then
    return ICONS.ssh, ICON_COLORS.ssh
  end
  if pane_title == "nvim" or process_name == "nvim" then
    return ICONS.neovim, ICON_COLORS.neovim
  end
  if is_claude then
    return ICONS.claude, ICON_COLORS.claude
  end
  if process_name == "docker" or (pane_title and pane_title:find("docker")) then
    return ICONS.docker, ICON_COLORS.docker
  end
  return ICONS.fallback, TAB_COLORS.foreground_inactive
end

local function get_tab_colors(is_active, is_ssh)
  if is_active and is_ssh then
    return TAB_COLORS.background_ssh_active, TAB_COLORS.foreground_ssh_active
  elseif is_active then
    return TAB_COLORS.background_active, TAB_COLORS.foreground_active
  end
  return TAB_COLORS.background_inactive, TAB_COLORS.foreground_inactive
end

local function has_zoomed_pane(panes)
  for _, pane_info in ipairs(panes) do
    if pane_info.is_zoomed then
      return true
    end
  end
  return false
end

function M.setup(config)
  local title_cache = {}
  local raw_cwd_cache = {}
  local ssh_host_cache = {}
  local claude_cache = {}

  -- cwd/Claude Code検出のキャッシュ更新(重い処理を毎描画走らせないため)
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

    local process_name = basename(pane:get_foreground_process_name() or "")
    local pane_title = pane:get_title() or ""
    if is_claude_process(process_name, pane_title) then
      claude_cache[pane_id] = true
    elseif (process_name == "zsh" or process_name == "bash" or process_name == "fish")
      and not (pane_title:find("^✳") or pane_title:lower():find("claude")) then
      claude_cache[pane_id] = nil
    end
  end)

  wezterm.on("format-tab-title", function(tab, _, _, _, _, max_width)
    local pane = tab.active_pane
    local pane_id = pane.pane_id
    local process_name = basename(pane.foreground_process_name)
    local pane_title = sanitize_title(pane.title or "")
    local cmdline = pane.foreground_process_name or ""
    local user_vars = pane.user_vars or {}
    local cached_cwd = title_cache[pane_id] or ""

    local is_ssh, ssh_host = is_ssh_process(process_name, cmdline, user_vars)
    if is_ssh and ssh_host then
      ssh_host_cache[pane_id] = ssh_host
    elseif not is_ssh then
      ssh_host_cache[pane_id] = nil
    end

    local is_claude = claude_cache[pane_id] or false

    local background, foreground = get_tab_colors(tab.is_active, is_ssh)
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

    local claude_suffix = ""
    if not custom and is_claude and pane_title ~= "" then
      claude_suffix = " " .. pane_title
    end

    local icon, icon_color = get_icon_and_color(process_name, pane_title, cached_cwd, is_ssh, is_claude)
    local zoom_indicator = has_zoomed_pane(tab.panes) and (ICONS.zoom .. " ") or ""
    local left_circle = tab.is_active and DECORATIONS.left_circle or ""
    local right_circle = tab.is_active and DECORATIONS.right_circle or ""

    local title = " " .. wezterm.truncate_right(title_text, max_width)
    local claude_title = wezterm.truncate_right(claude_suffix, max_width) .. " "

    return {
      { Background = { Color = edge_background } },
      { Text = " " },
      { Foreground = { Color = edge_foreground } },
      { Text = left_circle },
      { Background = { Color = background } },
      { Foreground = { Color = icon_color } },
      { Text = icon },
      { Background = { Color = background } },
      { Foreground = { Color = foreground } },
      { Text = zoom_indicator },
      { Attribute = { Intensity = "Bold" } },
      { Text = title },
      { Attribute = { Intensity = "Normal" } },
      { Text = claude_title },
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
