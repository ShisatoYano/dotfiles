local wezterm = require("wezterm")
local monokai_pro = require("colors.monokai-pro")
local M = {}

function M.setup(config)
  monokai_pro.register_color_schemes(config)

  config.font = wezterm.font("JetBrainsMono Nerd Font Mono")
  config.font_size = 10.0
  config.color_scheme = "Dracula (Official)"
  config.window_decorations = "RESIZE"
  config.window_padding = {
    left = 5,
    right = 5,
    top = 5,
    bottom = 5,
  }
  config.automatically_reload_config = true
  -- タブバーの見た目調整
  config.show_new_tab_button_in_tab_bar = false -- 新規タブの「+」を消す
  -- fancy tab bar(ネイティブの×ボタン/タブ境界線)を無効化し、
  -- tab_title.luaの丸cap形状だけでタブを表現する(retro描画)
  config.use_fancy_tab_bar = false
  config.window_frame = {
    inactive_titlebar_bg = "none",
    active_titlebar_bg = "none",
  }
  config.tab_bar_at_bottom = true -- タブバーを画面下部に表示
  config.tab_max_width = 40 -- タブタイトルが途中で切れないよう広めに確保
  -- 背景を透過(GNOME/Mutterはリアルタイムのぼかしに対応していないため透過のみ)
  config.window_background_opacity = 0.86
  -- "Hold"だと、wezterm-sessionsが復元処理で不要になった初期タブを閉じるために
  -- 送る"exit"コマンドの後もペインが残ってしまうため、正常終了時は自動で閉じる設定にする
  config.exit_behavior = "CloseOnCleanExit"
  -- 非アクティブなペインを暗く/彩度を落として表示し、アクティブなペインが一目で分かるようにする
  config.inactive_pane_hsb = {
    saturation = 0.9,
    brightness = 0.4,
  }
  -- コピーモードの選択範囲が背景色とほぼ同化して見づらいため上書きする
  -- (Dracula標準のselection色は背景に近すぎるため)
  config.colors = {
    selection_bg = "#6272a4",
    selection_fg = "#f8f8f2",
  }
end

return M
