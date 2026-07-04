local wezterm = require("wezterm")
local config = wezterm.config_builder()

require("config.appearance").setup(config)
require("config.keybinds").setup(config)

return config
