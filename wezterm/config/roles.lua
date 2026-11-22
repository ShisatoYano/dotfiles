local wezterm = require("wezterm")
local act = wezterm.action
local claude_cli = require("config.claude_cli")
local M = {}

-- config_dir経由の相対パスにしない。Claude Codeは..をシンボリックリンク解決前に畳むため~/.config/claudeと解釈される
local ROLES_DIR = wezterm.home_dir .. "/dotfiles/claude/roles/"

local ROLES = {
  { id = "lead", label = "司令塔(lead): 調査・計画・指示・受け入れ検証" },
  { id = "worker", label = "実装(worker): 指示書どおりに実装・テスト・コミット", settings = true },
}

local function shell_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- サブディレクトリから起動しても、司令塔と実装役がそろってリポジトリの最上位から始まるようにする
local function launch_dir(pane)
  local cwd_url = pane:get_current_working_dir()
  local cwd = cwd_url and cwd_url.file_path or wezterm.home_dir
  local ok, stdout = wezterm.run_child_process({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })
  if ok then
    return (stdout:gsub("%s+$", ""))
  end
  return cwd
end

-- 実装役を閉じ忘れたまま次を起動しても宛先の名前が重ならないよう、生きている名前と被れば連番にする
local function unique_name(base)
  local taken = {}
  for _, a in ipairs(claude_cli.agents()) do
    if a.name then
      taken[a.name] = true
    end
  end
  local name, n = base, 1
  while taken[name] do
    n = n + 1
    name = base .. "-" .. n
  end
  return name
end

local function spawn_role(window, pane, role)
  local name = unique_name(window:active_workspace() .. "-" .. role.id)
  local argv = {
    claude_cli.executable(),
    "-n",
    name,
    -- 両セッションのモードをそろえる。違うと相手からのメッセージが承認待ちで止まる
    "--permission-mode",
    "auto",
    -- --agentは既定のシステムプロンプトを置き換えてしまうため、末尾に足す方式にする
    "--append-system-prompt-file",
    ROLES_DIR .. role.id .. ".md",
  }
  if role.settings then
    table.insert(argv, "--settings")
    table.insert(argv, ROLES_DIR .. role.id .. ".json")
  end
  local quoted = {}
  for _, a in ipairs(argv) do
    table.insert(quoted, shell_quote(a))
  end
  -- `bash -lc`で包まず、対話シェルに打ち込む。包むとclaudeが前面プロセスにならず(処理中の状態が出ない)、
  -- .bashrcも非対話として途中で抜けるため、Bashツールの環境(PATH・ROS 2のsource等)が普段と変わる
  local tab, new_pane = window:mux_window():spawn_tab({ cwd = launch_dir(pane) })
  tab:activate()
  new_pane:send_text(table.concat(quoted, " ") .. "\n")
  window:toast_notification("WezTerm", "「" .. name .. "」を起動しました", nil, 3000)
end

local function role_picker(window, pane)
  local choices = {}
  for _, role in ipairs(ROLES) do
    table.insert(choices, { id = role.id, label = role.label })
  end
  window:perform_action(
    act.InputSelector({
      title = "Claude Codeを役割付きで起動",
      choices = choices,
      action = wezterm.action_callback(function(win, p, id)
        for _, role in ipairs(ROLES) do
          if role.id == id then
            spawn_role(win, p, role)
          end
        end
      end),
    }),
    pane
  )
end

function M.setup(config)
  config.keys = config.keys or {}
  table.insert(config.keys, { key = "o", mods = "LEADER", action = wezterm.action_callback(role_picker) })
end

return M
