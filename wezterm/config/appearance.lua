local wezterm = require("wezterm")
local theme = require("config.theme")
local M = {}

-- "#RRGGBB"をWezTermの"rgba(r, g, b, a)"形式に変換する(アルファチャンネル指定用)
local function hex_to_rgba(hex, alpha)
  local r = tonumber(hex:sub(2, 3), 16)
  local g = tonumber(hex:sub(4, 5), 16)
  local b = tonumber(hex:sub(6, 7), 16)
  return string.format("rgba(%d, %d, %d, %.2f)", r, g, b, alpha)
end

local function register_transparent_tab_bar(config, scheme_name)
  -- config.theme.custom_schemesで登録したカスタムスキームはbuiltinに存在しないため、
  -- 先にconfig.color_schemes(theme.setupで登録済み)を見る
  local scheme = (config.color_schemes or {})[scheme_name] or wezterm.get_builtin_color_schemes()[scheme_name]
  scheme.tab_bar = scheme.tab_bar or {}
  scheme.tab_bar.background = hex_to_rgba(scheme.background, 0)
  config.color_schemes = config.color_schemes or {}
  config.color_schemes[scheme_name] = scheme
end

function M.setup(config)
  config.font = wezterm.font("JetBrainsMono Nerd Font Mono")
  config.font_size = 10.0
  config.color_scheme = theme.dark_scheme

  register_transparent_tab_bar(config, theme.dark_scheme)
  register_transparent_tab_bar(config, theme.light_scheme)

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
  config.window_background_opacity = theme.dark_opacity
  -- "Hold"だと、wezterm-sessionsが復元処理で不要になった初期タブを閉じるために
  -- 送る"exit"コマンドの後もペインが残ってしまうため、正常終了時は自動で閉じる設定にする
  config.exit_behavior = "CloseOnCleanExit"
  -- 非アクティブなペインを暗く/彩度を落として表示し、アクティブなペインが一目で分かるようにする
  config.inactive_pane_hsb = {
    saturation = 1.0,
    brightness = 1.0,
  }
  -- コピーモードの選択範囲が背景色とほぼ同化して見づらいため上書きする
  -- (Dracula標準のselection色は背景に近すぎるため)
  config.colors = {
    selection_bg = "#6272a4",
    selection_fg = "#f8f8f2",
  }
end

return M
