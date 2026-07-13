local wezterm = require("wezterm")
local M = {}

-- 与えられたペインを、右側30%・左側は上下7:3に分割する
-- (WezTerm起動時の最初のタブにも、新規タブ作成時にも使う共通ロジック)
function M.apply_layout(pane)
  pane:split({ direction = "Right", size = 0.3 })
  pane:split({ direction = "Bottom", size = 0.3 })
end

-- 新規タブを、上記レイアウトが適用された状態で作成する
local function spawn_split_tab(window, pane)
  local mux_window = window:mux_window()
  local _, left_pane = mux_window:spawn_tab({})
  M.apply_layout(left_pane)
end

function M.setup(config)
  config.keys = config.keys or {}
  -- デフォルトの新規タブキー(Ctrl+Shift+T)を上書き
  table.insert(config.keys, {
    key = "T",
    mods = "CTRL|SHIFT",
    action = wezterm.action_callback(spawn_split_tab),
  })
end

return M
