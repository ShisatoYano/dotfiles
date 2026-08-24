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

wezterm.on("toggle-color-scheme", function(window, _)
  local overrides = window:get_config_overrides() or {}
  if overrides.color_scheme == M.light_scheme then
    overrides.color_scheme = M.dark_scheme
    overrides.window_background_opacity = M.dark_opacity
  else
    overrides.color_scheme = M.light_scheme
    overrides.window_background_opacity = M.light_opacity
  end
  window:set_config_overrides(overrides)
end)

return M
