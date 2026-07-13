local wezterm = require("wezterm")
local sessions = wezterm.plugin.require("https://github.com/abidibo/wezterm-sessions")
local tab_layout = require("config.tab_layout")
local M = {}

local STATE_DIR = wezterm.home_dir .. "/.local/share/wezterm-sessions/state/"

local function escape_file_name(name)
  return (name:gsub("[^%w_%-]", "_"))
end

local function has_saved_state(workspace_name)
  local file_path = STATE_DIR .. "wezterm_state_" .. escape_file_name(workspace_name) .. ".json"
  local f = io.open(file_path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

-- GUIウィンドウがまだ生成されていないことがあるため、生成されるまでリトライする
local function on_gui_ready(attempt)
  attempt = attempt or 0
  local gui_windows = wezterm.gui.gui_windows()

  if #gui_windows > 0 then
    local window = gui_windows[1]
    local workspace_name = window:active_workspace()

    -- 最大化(タスクバー等は隠さない)してから復元/レイアウト適用する
    -- (ペインの分割割合は最終的なウィンドウサイズを基準に計算されるため)
    window:maximize()

    if has_saved_state(workspace_name) then
      sessions.restore_state(window)
    else
      -- 保存済みの状態が無い場合(初回起動時など)は、既定のペインレイアウトを適用する
      local pane = window:mux_window():active_pane()
      tab_layout.apply_layout(pane)
    end

    sessions.start_autosave(window)
  elseif attempt < 40 then
    -- 最大 40 * 0.25s = 10秒までリトライ
    wezterm.time.call_after(0.25, function()
      on_gui_ready(attempt + 1)
    end)
  else
    wezterm.log_error("wezterm-sessions: GUI window did not become ready in time")
  end
end

wezterm.on("gui-startup", function(_)
  on_gui_ready()
end)

function M.setup(config)
  -- 手動での保存/復元/一覧選択などのキーバインドも合わせて有効化
  -- ALT+s 保存 / ALT+l 一覧から読み込み / ALT+r 復元 / ALT+a 自動保存トグル / ALT+f フォーク
  -- Ctrl+Shift+d 削除 / Ctrl+Shift+e 編集
  sessions.apply_to_config(config, {
    auto_save_interval_s = 10,
    save_state_dir = "default-user-owned", -- ~/.local/share/wezterm-sessions/state/ に保存(プラグイン更新の影響を受けない)
  })
end

return M
