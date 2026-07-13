local wezterm = require("wezterm")
local monokai_pro = require("colors.monokai-pro")
local M = {}

function M.setup(config)
  monokai_pro.register_color_schemes(config)

  config.font = wezterm.font("JetBrainsMono Nerd Font Mono")
  config.font_size = 12.0
  config.color_scheme = "Monokai Pro (Pro)"
  config.window_decorations = "RESIZE"
  config.window_padding = {
    left = 5,
    right = 5,
    top = 5,
    bottom = 5,
  }
  config.automatically_reload_config = true
  -- 背景を透過(GNOME/Mutterはリアルタイムのぼかしに対応していないため透過のみ)
  config.window_background_opacity = 0.9
  -- "Hold"だと、wezterm-sessionsが復元処理で不要になった初期タブを閉じるために
  -- 送る"exit"コマンドの後もペインが残ってしまうため、正常終了時は自動で閉じる設定にする
  config.exit_behavior = "CloseOnCleanExit"
end

return M
