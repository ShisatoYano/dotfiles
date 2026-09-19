local wezterm = require("wezterm")
local M = {}

-- Dark theme settings
M.dark_scheme = "Solarized Osaka"
M.dark_opacity = 0.87

-- Light theme settings
M.light_scheme = "Builtin Solarized Light"
M.light_opacity = 1.0

-- お試し用のカスタムテーマ置き場。ここに追加するだけでconfig.color_schemesに登録され、
-- 上のM.dark_scheme/M.light_schemeの値をこのキー名に差し替えれば使える
-- (automatically_reload_config有効のため保存するだけで反映される)
M.custom_schemes = {
  ["Solarized Osaka"] = require("config.colorschemes.solarized_osaka"),
}

function M.setup(config)
  config.color_schemes = config.color_schemes or {}
  for name, scheme in pairs(M.custom_schemes) do
    config.color_schemes[name] = scheme
  end
end

-- ウィンドウごとのライト/ダーク状態。設定リロードのたびにLuaの状態は作り直されるため、
-- リロードをまたいで保持されるwezterm.GLOBALに置く
-- (overridesのcolor_scheme名から判定すると、上のM.light_schemeを別名に差し替えた瞬間に
--  ライト表示中のウィンドウがダーク扱いになってしまう)
local function get_light_state(window)
  return (wezterm.GLOBAL.theme_is_light or {})[tostring(window:window_id())]
end

local function set_light_state(window, is_light)
  -- wezterm.GLOBAL配下のテーブルは直接書き換えても保持されないため、代入し直す
  local states = wezterm.GLOBAL.theme_is_light or {}
  states[tostring(window:window_id())] = is_light
  wezterm.GLOBAL.theme_is_light = states
end

local function apply(window, is_light)
  local overrides = window:get_config_overrides() or {}
  local scheme = is_light and M.light_scheme or M.dark_scheme
  local opacity = is_light and M.light_opacity or M.dark_opacity
  -- set_config_overridesはwindow-config-reloadedを再発火させるので、
  -- 差分がないときは呼ばずに無限ループを避ける
  if overrides.color_scheme == scheme and overrides.window_background_opacity == opacity then
    return
  end
  overrides.color_scheme = scheme
  overrides.window_background_opacity = opacity
  window:set_config_overrides(overrides)
end

wezterm.on("toggle-color-scheme", function(window, _)
  local is_light = not get_light_state(window)
  set_light_state(window, is_light)
  apply(window, is_light)
end)

-- set_config_overridesの値は設定ファイルより優先され、ウィンドウを閉じるまで残る。
-- 貼り直さないと、一度でもトグルしたウィンドウには上のschemeやopacityの編集が
-- 二度と反映されない(リロード自体は効いているのに効いていないように見える)
wezterm.on("window-config-reloaded", function(window)
  local is_light = get_light_state(window)
  if is_light == nil then
    return -- 未トグルのウィンドウはoverridesがなく、config側の値がそのまま効く
  end
  apply(window, is_light)
end)

return M
