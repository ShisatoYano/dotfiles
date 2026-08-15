local wezterm = require("wezterm")
local config = wezterm.config_builder()

require("config.theme") -- toggle-color-schemeイベントを登録するため読み込むだけでOK
require("config.appearance").setup(config)
require("config.keybinds").setup(config) -- config.keys/config.key_tablesを直接代入するので最初に呼ぶ
require("config.cmdpicker").setup(config)
require("config.tab_title").setup(config)
require("config.sessions").setup(config)
require("config.worktree_workspace").setup(config)

return config
