local wezterm = require("wezterm")
local tab_title = require("config.tab_title")
local M = {}

function M.setup(config)
  config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }
  config.keys = {
    { key = "v", mods = "LEADER", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "s", mods = "LEADER", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "h", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Left") },
    { key = "j", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Down") },
    { key = "k", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Up") },
    { key = "l", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Right") },
    { key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = true }) },
    -- コピーモードに入る(デフォルトのCtrl+Shift+Xは押しにくいためleader経由に変更)
    { key = "c", mods = "LEADER", action = wezterm.action.ActivateCopyMode },
    -- スクロールバックを1ページ分移動(PageUp/PageDownはFn併用が必要で押しにくいため)
    { key = "u", mods = "LEADER", action = wezterm.action.ScrollByPage(-1) },
    { key = "d", mods = "LEADER", action = wezterm.action.ScrollByPage(1) },
    -- ペインサイズの微調整(LEADER + 矢印キーで2セル分ずつリサイズ)
    { key = "LeftArrow", mods = "LEADER", action = wezterm.action.AdjustPaneSize({ "Left", 2 }) },
    { key = "RightArrow", mods = "LEADER", action = wezterm.action.AdjustPaneSize({ "Right", 2 }) },
    { key = "UpArrow", mods = "LEADER", action = wezterm.action.AdjustPaneSize({ "Up", 2 }) },
    { key = "DownArrow", mods = "LEADER", action = wezterm.action.AdjustPaneSize({ "Down", 2 }) },
    -- ライト/ダーク配色を瞬時に切り替え
    { key = "t", mods = "LEADER", action = wezterm.action.EmitEvent("toggle-color-scheme") },
    -- WezTermを終了(全ウィンドウ/タブを閉じる)
    { key = "q", mods = "LEADER", action = wezterm.action.QuitApplication },
    -- タブ一覧を表示して選択切り替え(プロジェクト名がわかる自作ピッカー)
    { key = "g", mods = "LEADER", action = tab_title.tab_picker() },
  }
end

return M
