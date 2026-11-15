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

-- 直前のコマンドの出力をコピーする(シェル統合のOSC 133が前提)
local function copy_last_command_output(window, pane)
  -- 最後のOutputゾーンは使わない: TUI(Claude Code等)が消去した画面下部の空セルが、現在のプロンプトより下にOutputとして残るため。
  -- 直前のコマンドは「最後から2番目のPrompt」と「最後のPrompt(入力待ち)」の間として求める
  local prompts = pane:get_semantic_zones("Prompt")
  local last, prev = prompts[#prompts], prompts[#prompts - 1]
  local text = ""
  if prev then
    for _, zone in ipairs(pane:get_semantic_zones("Output")) do
      if zone.start_y >= prev.end_y and zone.start_y < last.start_y then
        -- このWezTerm(20240203)のget_text_from_regionはend_yの行を含まないため、次のPromptの行で止めれば直前の行まで入る
        text = pane:get_text_from_region(zone.start_x, zone.start_y, 0, last.start_y):gsub("%s+$", "")
        break
      end
    end
  end
  if text == "" then
    window:toast_notification("WezTerm", "直前のコマンドに出力がありません", nil, 2000)
    return
  end
  window:copy_to_clipboard(text)
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

  -- Activate tab by index: LEADER+1..9 (10番目以降は<leader>gのピッカーで選ぶ)
  for i = 1, 9 do
    table.insert(config.keys, { key = tostring(i), mods = "LEADER", action = wezterm.action.ActivateTab(i - 1) })
  end

  -- Copy mode: 既定のyは「コピーして抜ける」のまま、Yを「コピーしてモードに残る」にする
  -- (既定のY=行単位コピーはV→yで代替できる)。後から追加した割り当てが優先される
  local copy_mode = wezterm.gui.default_key_tables().copy_mode
  table.insert(copy_mode, {
    key = "Y",
    mods = "SHIFT",
    action = wezterm.action.Multiple({
      { CopyTo = "ClipboardAndPrimarySelection" },
      { CopyMode = "ClearSelectionMode" },
    }),
  })

  -- Key tables 
  config.key_tables = {
    resize_pane = {
      { key = "h", action = wezterm.action.AdjustPaneSize({ "Left", 1 }) },
      { key = "j", action = wezterm.action.AdjustPaneSize({ "Down", 1 }) },
      { key = "k", action = wezterm.action.AdjustPaneSize({ "Up", 1 }) },
      { key = "l", action = wezterm.action.AdjustPaneSize({ "Right", 1 }) },
      { key = "Enter", action = "PopKeyTable" },
    }, 
    copy_mode = copy_mode,
  }
end

return M
