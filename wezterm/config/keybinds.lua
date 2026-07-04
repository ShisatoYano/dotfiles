local wezterm = require("wezterm")
local M = {}

function M.setup(config)
  config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }
  config.keys = {
    { key = "|", mods = "LEADER|SHIFT", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "-", mods = "LEADER", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "h", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Left") },
    { key = "j", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Down") },
    { key = "k", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Up") },
    { key = "l", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Right") },
    { key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = true }) },
  }
end

return M
