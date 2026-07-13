local wezterm = require("wezterm")
local M = {}

M.dark_scheme = "Monokai Pro (Pro)"
M.light_scheme = "Monokai Pro (Light)"
-- 背景の透過はダークテーマのときだけ有効にする
M.dark_opacity = 0.9
M.light_opacity = 1.0

wezterm.on("toggle-color-scheme", function(window, pane)
  local overrides = window:get_config_overrides() or {}
  if overrides.color_scheme == M.light_scheme then
    overrides.color_scheme = M.dark_scheme
    overrides.window_background_opacity = M.dark_opacity
  else
    overrides.color_scheme = M.light_scheme
    overrides.window_background_opacity = M.light_opacity
  end
  window:set_config_overrides(overrides)
end)

return M
