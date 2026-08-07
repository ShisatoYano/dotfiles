local wezterm = require("wezterm")
local M = {}

-- Dark theme settings
M.dark_scheme = "Dracula (Official)"
M.dark_opacity = 0.86

-- Light theme settings
M.light_scheme = "Builtin Solarized Light"
M.light_opacity = 1.0

wezterm.on("toggle-color-scheme", function(window, _)
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
