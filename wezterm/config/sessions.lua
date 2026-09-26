local wezterm = require("wezterm")
local sessions = wezterm.plugin.require("https://github.com/abidibo/wezterm-sessions")
local M = {}

M.AUTO_SAVE_INTERVAL_S = 10

M.STATE_DIR = wezterm.home_dir .. "/.local/share/wezterm-sessions/state/"

function M.escape_file_name(name)
  return (name:gsub("[^%w_%-]", "_"))
end

local function has_saved_state(workspace_name)
  local file_path = M.STATE_DIR .. "wezterm_state_" .. M.escape_file_name(workspace_name) .. ".json"
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

    -- 最大化(タスクバー等は隠さない)してから復元する
    window:maximize()

    if has_saved_state(workspace_name) then
      sessions.restore_state(window)
    end

    wezterm.GLOBAL.sessions_restoring = false
  elseif attempt < 40 then
    -- 最大 40 * 0.25s = 10秒までリトライ
    wezterm.time.call_after(0.25, function()
      on_gui_ready(attempt + 1)
    end)
  else
    wezterm.GLOBAL.sessions_restoring = false
    wezterm.log_error("wezterm-sessions: GUI window did not become ready in time")
  end
end

-- プラグインのstart_autosaveはcall_afterの再予約ループで、設定リロードで世代が変わると
-- 黙ってスキップされ、コールバック内のエラーも握りつぶされて以後二度と保存されなくなる。
-- update-statusはリロードのたびに登録し直され毎秒発火するので、これを間引いて自動保存に使う
local last_auto_save = 0
wezterm.on("update-status", function(window, _)
  if wezterm.GLOBAL.sessions_restoring then
    return
  end
  local now = os.time()
  if now - last_auto_save < M.AUTO_SAVE_INTERVAL_S then
    return
  end
  last_auto_save = now

  -- 終了途中などでタブが無い状態を保存すると、正常な保存内容を空で上書きしてしまう
  local mux_window = window:mux_window()
  if not mux_window or #mux_window:tabs() == 0 then
    return
  end

  local ok, err = pcall(sessions.save_state, window, false)
  if not ok then
    wezterm.log_error("wezterm-sessions: auto save failed: " .. tostring(err))
  end
end)

wezterm.on("gui-startup", function(_)
  -- 復元前の初期タブ1枚だけの状態で上書きしないよう、復元が終わるまで自動保存を止める。
  -- 設定リロードでLua状態が作り直されても消えないようGLOBALに持つ
  wezterm.GLOBAL.sessions_restoring = true
  on_gui_ready()
end)

-- 自動保存は一定間隔(AUTO_SAVE_INTERVAL_S)でしか走らないため、
-- 直前にタブを開閉した直後にウィンドウを閉じると保存が間に合わないことがある。
-- ウィンドウが閉じられる直前に同期的に保存することで取りこぼしを防ぐ。
wezterm.on("window-close-requested", function(window, _)
  sessions.save_state(window, false)
end)

function M.setup(config)
  -- 手動での保存/復元/一覧選択などのキーバインドも合わせて有効化
  -- ALT+s 保存 / ALT+l 一覧から読み込み / ALT+r 復元 / ALT+a 自動保存トグル / ALT+f フォーク
  -- Ctrl+Shift+d 削除 / Ctrl+Shift+e 編集
  sessions.apply_to_config(config, {
    auto_save_interval_s = M.AUTO_SAVE_INTERVAL_S, -- ALT+aでプラグイン側の自動保存を有効化した場合のみ使われる
    save_state_dir = "default-user-owned", -- ~/.local/share/wezterm-sessions/state/ に保存(プラグイン更新の影響を受けない)
  })
end

return M
