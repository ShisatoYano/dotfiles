local wezterm = require("wezterm")
local config = wezterm.config_builder()

require("config.theme").setup(config) -- toggle-color-schemeイベント登録 + カスタムカラースキーム登録 + 状態ファイルに応じた配色・透過度の設定
require("config.appearance").setup(config)
require("config.keybinds").setup(config) -- config.keys/config.key_tablesを直接代入するので最初に呼ぶ
require("config.smart-splits").setup(config) -- Ctrl+h/j/k/lでリーダー不要のペイン移動(nvimのsmart-splits.nvimと連携)
require("config.cmdpicker").setup(config)
require("config.tab_title").setup(config)
require("config.sessions").setup(config)

return config
