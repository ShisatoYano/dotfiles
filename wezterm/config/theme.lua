local wezterm = require("wezterm")
local M = {}

M.dark_scheme = "Monokai Pro (Pro)"
M.light_scheme = "Github (Gogh)"

wezterm.on("toggle-color-scheme", function(window, pane)
  local overrides = window:get_config_overrides() or {}
  if overrides.color_scheme == M.light_scheme then
    overrides.color_scheme = M.dark_scheme
  else
    overrides.color_scheme = M.light_scheme
  end
  window:set_config_overrides(overrides)
end)

return M
