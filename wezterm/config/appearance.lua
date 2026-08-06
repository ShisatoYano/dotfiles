local wezterm = require("wezterm")
local M = {}

-- "#RRGGBB"をWezTermの"rgba(r, g, b, a)"形式に変換する(アルファチャンネル指定用)
local function hex_to_rgba(hex, alpha)
  local r = tonumber(hex:sub(2, 3), 16)
  local g = tonumber(hex:sub(4, 5), 16)
  local b = tonumber(hex:sub(6, 7), 16)
  return string.format("rgba(%d, %d, %d, %.2f)", r, g, b, alpha)
end

function M.setup(config)
  config.font = wezterm.font("JetBrainsMono Nerd Font Mono")
  config.font_size = 10.0
  config.color_scheme = "Dracula (Official)"

  -- 組み込みDraculaスキームはtab_bar.backgroundが不透明な固定色のため、
  -- タブの無い末尾の余白だけwindow_background_opacityの透過が反映されない。
  -- retroタブバー(use_fancy_tab_bar = false)は単なるテキスト行として描画され、
  -- 中間的なアルファ値によるブレンド合成には対応していない(wezterm側の既知の制約:
  -- https://github.com/wezterm/wezterm/issues/3563#issuecomment-1515479566)。
  -- アルファ0(完全な透過)を指定した場合のみ描画自体がスキップされ、
  -- tab_title.luaのcap部分と同様にウィンドウ本来の透過が反映される。
  -- (color_schemeを指定すると、config.colorsによるトップレベルの上書きは無視されるため
  --  スキーム自体を複製してtab_bar.backgroundだけ差し替え、同名で再登録する)
  local dracula = wezterm.get_builtin_color_schemes()["Dracula (Official)"]
  dracula.tab_bar.background = hex_to_rgba(dracula.tab_bar.background, 0)
  config.color_schemes = { ["Dracula (Official)"] = dracula }

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
