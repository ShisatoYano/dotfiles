local wezterm = require("wezterm")
local tab_title = require("config.tab_title")
local theme = require("config.theme")
local M = {}

-- Key table of mode label
local KEY_TABLE_LABELS = {
  resize_pane = "RESIZE_MODE",
}

-- Display active mode on status area.
-- config reloadのたびにLuaインタプリタ状態は作り直され、古いreloadで登録した
-- wezterm.onは自然に破棄されるため、多重登録を気にして登録をガードする必要はない
-- (むしろガードすると、reload後もこのハンドラの中身が最初の版のまま固定されてしまう)
wezterm.on("update-right-status", function(window, _)
  local colors = window:effective_config().color_scheme == theme.light_scheme
    and tab_title.TAB_COLORS_LIGHT
    or tab_title.TAB_COLORS_DARK

  local segments = {}

  local key_table_name = window:active_key_table()
  if key_table_name then
    local label = KEY_TABLE_LABELS[key_table_name] or key_table_name:upper()
    table.insert(segments, {
      { Foreground = { Color = colors.foreground_active } },
      { Background = { Color = colors.background_active } },
      { Attribute = { Intensity = "Bold" } },
      { Text = "  " .. label .. "  " },
    })
  end

  local formatted = {}
  for _, segment in ipairs(segments) do
    for _, item in ipairs(segment) do
      table.insert(formatted, item)
    end
  end
  window:set_right_status(wezterm.format(formatted))
end)

-- 直前のコマンド行とその出力をまとめてコピーする(シェル統合のOSC 133が前提)
local function copy_last_command_output(window, pane)
  local outputs = pane:get_semantic_zones("Output")
  local output = outputs[#outputs]
  if not output then
    return
  end
  -- 末尾のInputは入力待ちの現在のプロンプトなので、出力より前にある最後のInputを起点にする
  local start = output
  for _, zone in ipairs(pane:get_semantic_zones("Input")) do
    if zone.start_y <= output.start_y then
      start = zone
    end
  end
  -- このWezTerm(20240203)のget_text_from_regionはend_yの行を含まないため+1する
  window:copy_to_clipboard(pane:get_text_from_region(start.start_x, start.start_y, output.end_x, output.end_y + 1))
end

function M.setup(config)
  -- Quick Select(Ctrl+Shift+Space)の標準パターン(ハッシュ/IP/URL等)に追加する
  config.quick_select_patterns = {
    "[\\w./~-]+\\.\\w+:\\d+(?::\\d+)?", -- path/to/file.py:123(:45)
    "(?:/[A-Za-z_][\\w]*){2,}", -- ROS 2トピック名・絶対パス
  }

  config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 2000 }
  config.keys = {
    -- Split pane
    { key = "v", mods = "LEADER", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "s", mods = "LEADER", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
    
    -- Activate pane: Ctrl+h/j/k/l (config.smart-splits側で設定、nvimとシームレスに連携)

    -- Close pane
    { key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = true }) },
    
    -- Activate Copy mode 
    { key = "c", mods = "LEADER", action = wezterm.action.ActivateCopyMode },
    
    -- Scroll up/down 
    { key = "u", mods = "LEADER", action = wezterm.action.ScrollByPage(-1) },
    { key = "d", mods = "LEADER", action = wezterm.action.ScrollByPage(1) },

    -- Jump to previous/next prompt, copy last command and its output (OSC 133)
    { key = "[", mods = "LEADER", action = wezterm.action.ScrollToPrompt(-1) },
    { key = "]", mods = "LEADER", action = wezterm.action.ScrollToPrompt(1) },
    { key = "z", mods = "LEADER", action = wezterm.action_callback(copy_last_command_output) },

    -- Resize pane 
    { key = "r", mods = "LEADER", action = wezterm.action.ActivateKeyTable({ name = "resize_pane", one_shot = false }) },

    -- Switch color scheme dark/light
    { key = "t", mods = "LEADER", action = wezterm.action.EmitEvent("toggle-color-scheme") },
    
    -- Terminate WezTerm
    { key = "q", mods = "LEADER", action = wezterm.action.QuitApplication },
    
    -- Select tab
    { key = "g", mods = "LEADER", action = tab_title.tab_picker() },

    -- Switch tab (nvimのバッファ切り替え<S-h>/<S-l>に合わせたキー)
    { key = "H", mods = "LEADER|SHIFT", action = wezterm.action.ActivateTabRelative(-1) },
    { key = "L", mods = "LEADER|SHIFT", action = wezterm.action.ActivateTabRelative(1) },

    -- Resize font
    { key = "+", mods = "CTRL", action = wezterm.action.IncreaseFontSize },
    { key = "-", mods = "CTRL", action = wezterm.action.DecreaseFontSize },
    { key = "0", mods = "CTRL", action = wezterm.action.ResetFontSize },
  }

  -- Key tables 
  config.key_tables = {
    resize_pane = {
      { key = "h", action = wezterm.action.AdjustPaneSize({ "Left", 1 }) },
      { key = "j", action = wezterm.action.AdjustPaneSize({ "Down", 1 }) },
      { key = "k", action = wezterm.action.AdjustPaneSize({ "Up", 1 }) },
      { key = "l", action = wezterm.action.AdjustPaneSize({ "Right", 1 }) },
      { key = "Enter", action = "PopKeyTable" },
    }, 
  }
end

return M
