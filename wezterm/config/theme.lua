local wezterm = require("wezterm")
local M = {}

-- Dark theme settings
M.dark_scheme = "Solarized Osaka"
M.dark_opacity = 0.85 -- 背景を透過(GNOME/Mutterはリアルタイムのぼかしに対応していないため透過のみ)

-- Light theme settings
M.light_scheme = "Builtin Solarized Light"
M.light_opacity = 1.0

-- お試し用のカスタムテーマ置き場。ここに追加するだけでconfig.color_schemesに登録され、
-- 上のM.dark_scheme/M.light_schemeの値をこのキー名に差し替えれば使える
-- (automatically_reload_config有効のため保存するだけで反映される)
M.custom_schemes = {
  ["Solarized Osaka"] = require("config.colorschemes.solarized_osaka"),
}

-- ライト/ダークの唯一の状態。nvim(plugins/colorscheme.lua)も同じファイルを読み書き・監視しており、
-- どちらでトグルしても両方が追従する
M.state_file = wezterm.home_dir .. "/.local/state/theme-mode"

function M.is_light()
  local f = io.open(M.state_file, "r")
  if not f then
    return false
  end
  local mode = f:read("*l")
  f:close()
  return mode == "light"
end

local function write_mode(is_light)
  local f, err = io.open(M.state_file, "w")
  if not f then
    wezterm.log_error("theme: failed to write " .. M.state_file .. ": " .. tostring(err))
    return
  end
  f:write(is_light and "light\n" or "dark\n")
  f:close()
end

function M.setup(config)
  config.color_schemes = config.color_schemes or {}
  for name, scheme in pairs(M.custom_schemes) do
    config.color_schemes[name] = scheme
  end

  -- 存在しないパスは監視できないため、初回だけダークで作っておく
  local f = io.open(M.state_file, "r")
  if f then
    f:close()
  else
    write_mode(false)
  end
  -- ファイルが書き換わると設定ごとリロードされ、全ウィンドウに新しい配色が効く
  wezterm.add_to_config_reload_watch_list(M.state_file)

  local is_light = M.is_light()
  config.color_scheme = is_light and M.light_scheme or M.dark_scheme
  config.window_background_opacity = is_light and M.light_opacity or M.dark_opacity
end

wezterm.on("toggle-color-scheme", function(_, _)
  write_mode(not M.is_light())
end)

-- Claude Code(theme=auto)は、テーマ変更通知(DEC mode 2031のCSI ?997;{1=dark,2=light}n)を受けると
-- OSC 11で背景色を問い合わせ直して配色を切り替える。このバージョンのWezTermは通知を自前で送らないため代わりに送る。
-- 他のプログラムには意味不明な入力になるので、Claudeが前面にいるペインだけに限る
local function notify_claude_panes(is_light)
  local seq = is_light and "\x1b[?997;2n" or "\x1b[?997;1n"
  for _, mux_window in ipairs(wezterm.mux.all_windows()) do
    for _, tab in ipairs(mux_window:tabs()) do
      for _, pane in ipairs(tab:panes()) do
        if (pane:get_foreground_process_name() or ""):match("claude[^/]*$") then
          pane:send_text(seq)
        end
      end
    end
  end
end

-- リロードはウィンドウ数だけ発火し、設定ファイル編集でも発火するため、
-- 前回値(リロードをまたいで残るwezterm.GLOBAL)と比べて変わったときだけ通知する
wezterm.on("window-config-reloaded", function(_)
  local mode = M.is_light() and "light" or "dark"
  local prev = wezterm.GLOBAL.theme_mode
  wezterm.GLOBAL.theme_mode = mode
  if prev ~= nil and prev ~= mode then
    notify_claude_panes(mode == "light")
  end
end)

return M
