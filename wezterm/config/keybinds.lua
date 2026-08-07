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
    -- ペインサイズの微調整モードに入る(以後leader不要でhjkl/矢印キーだけでリサイズ可能。Esc/Enter/qで抜ける)
    { key = "r", mods = "LEADER", action = wezterm.action.ActivateKeyTable({ name = "resize_pane", one_shot = false }) },
    -- ライト/ダーク配色を瞬時に切り替え
    { key = "t", mods = "LEADER", action = wezterm.action.EmitEvent("toggle-color-scheme") },
    -- WezTermを終了(全ウィンドウ/タブを閉じる)
    { key = "q", mods = "LEADER", action = wezterm.action.QuitApplication },
    -- タブ一覧を表示して選択切り替え(プロジェクト名がわかる自作ピッカー)
    { key = "g", mods = "LEADER", action = tab_title.tab_picker() },
  }

  -- LEADER+rで入るリサイズモード。抜けるまで2セル分ずつリサイズを繰り返せる
  config.key_tables = {
    resize_pane = {
      { key = "h", action = wezterm.action.AdjustPaneSize({ "Left", 2 }) },
      { key = "j", action = wezterm.action.AdjustPaneSize({ "Down", 2 }) },
      { key = "k", action = wezterm.action.AdjustPaneSize({ "Up", 2 }) },
      { key = "l", action = wezterm.action.AdjustPaneSize({ "Right", 2 }) },
      { key = "LeftArrow", action = wezterm.action.AdjustPaneSize({ "Left", 2 }) },
      { key = "RightArrow", action = wezterm.action.AdjustPaneSize({ "Right", 2 }) },
      { key = "UpArrow", action = wezterm.action.AdjustPaneSize({ "Up", 2 }) },
      { key = "DownArrow", action = wezterm.action.AdjustPaneSize({ "Down", 2 }) },
      { key = "Escape", action = "PopKeyTable" },
      { key = "Enter", action = "PopKeyTable" },
      { key = "q", action = "PopKeyTable" },
    },
  }
end

return M
