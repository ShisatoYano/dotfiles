local wezterm = require("wezterm")
local M = {}

function M.setup(config)
  config.font = wezterm.font("JetBrains Mono")
  config.font_size = 12.0
  config.color_scheme = "Monokai (Gogh)"
  config.window_decorations = "RESIZE"
  config.window_padding = {
    left = 5,
    right = 5,
    top = 5,
    bottom = 5,
  }
  config.automatically_reload_config = true
end

return M
