local wezterm = require("wezterm")
local config = wezterm.config_builder()

require("config.theme") -- toggle-color-schemeイベントを登録するため読み込むだけでOK
require("config.appearance").setup(config)
require("config.keybinds").setup(config)
require("config.cmdpicker").setup(config)
require("config.tab_layout").setup(config)

return config
