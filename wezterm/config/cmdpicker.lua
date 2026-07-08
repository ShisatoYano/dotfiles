local wezterm = require("wezterm")
local M = {}

function M.setup(config)
  local cmdpicker = wezterm.plugin.require("https://github.com/abidibo/wezterm-cmdpicker")
  cmdpicker.apply_to_config(config, {
    key = "?",
    mods = "LEADER|SHIFT",
    title = "Command Palette",
    include_defaults = true, -- WezTerm標準のキーも一緒に一覧表示
  })
end

return M
