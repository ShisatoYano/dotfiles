local wezterm = require("wezterm")
local M = {}

-- WezTermのOverlay(全画面の一時ペイン)はユーザーコマンド向けに公開されていないため、
-- ズームした分割ペインで代用する(exit_behavior="CloseOnCleanExit"なので終了で閉じる)
local function open_zoomed(window, pane, args)
  local cwd_url = pane:get_current_working_dir()
  local new_pane = pane:split({ args = args, cwd = cwd_url and cwd_url.file_path or nil })
  new_pane:activate()
  window:perform_action(wezterm.action.TogglePaneZoomState, new_pane)
end

local function open_command(args)
  return wezterm.action_callback(function(window, pane)
    open_zoomed(window, pane, args)
  end)
end

-- スクロールバック全体をnvimで開く(AIの出力中でも検索・コピーできるように)
local function open_scrollback_in_nvim(window, pane)
  -- os.tmpnameはmkstempで0600のファイルを作るので、他ユーザーからは読めない
  local path = os.tmpname()
  local f, err = io.open(path, "w")
  if not f then
    wezterm.log_error("overlay: failed to open temp file: " .. tostring(err))
    return
  end
  f:write(pane:get_lines_as_text(pane:get_dimensions().scrollback_rows))
  f:close()
  open_zoomed(window, pane, { "sh", "-c", 'nvim + "$1"; rm -f "$1"', "sh", path })
end

function M.setup(config)
  config.keys = config.keys or {}
  table.insert(config.keys, { key = "G", mods = "LEADER|SHIFT", action = open_command({ "lazygit" }) })
  table.insert(config.keys, { key = "P", mods = "LEADER|SHIFT", action = open_command({ "gh", "dash" }) })
  table.insert(config.keys, { key = "e", mods = "LEADER", action = wezterm.action_callback(open_scrollback_in_nvim) })
end

return M
