local wezterm = require("wezterm")
local M = {}

local function is_vim(pane)
  -- smart-splits.nvim がNeovim起動中にセットするユーザー変数を見る
  return pane:get_user_vars().IS_NVIM == "true"
end

local direction_keys = {
  h = "Left",
  j = "Down",
  k = "Up",
  l = "Right",
}

local function split_nav(key)
  return {
    key = key,
    mods = "CTRL",
    action = wezterm.action_callback(function(win, pane)
      if is_vim(pane) then
        -- Neovimが動いている場合は、キー入力をそのままNeovim側に渡す(smart-splitsが処理する)
        win:perform_action({ SendKey = { key = key, mods = "CTRL" } }, pane)
      else
        -- それ以外はWezTermのペイン移動
        win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
      end
    end),
  }
end

function M.setup(config)
  config.keys = config.keys or {}
  table.insert(config.keys, split_nav("h"))
  table.insert(config.keys, split_nav("j"))
  table.insert(config.keys, split_nav("k"))
  table.insert(config.keys, split_nav("l"))
end
