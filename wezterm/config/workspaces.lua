local wezterm = require("wezterm")
local act = wezterm.action
local sessions = require("config.sessions")
local tab_title = require("config.tab_title")
local M = {}

local INPUT_ID = "__input__"

local function basename(path)
  return (path:gsub("/+$", ""):match("([^/]+)$")) or path
end

-- ワークスペースごとのタブ数(count_busyなら処理中のClaudeの数も)を集計する
local function summarize(count_busy)
  local summary = {}
  for _, mux_win in ipairs(wezterm.mux.all_windows()) do
    local name = mux_win:get_workspace()
    local s = summary[name] or { tabs = 0, busy = 0 }
    for _, tab in ipairs(mux_win:tabs()) do
      s.tabs = s.tabs + 1
      if count_busy then
        for _, p in ipairs(tab:panes()) do
          if tab_title.is_claude_busy(p:get_foreground_process_name(), p:get_title()) then
            s.busy = s.busy + 1
          end
        end
      end
    end
    summary[name] = s
  end
  return summary
end

local function workspace_choices(window, exclude_current)
  local current = window:active_workspace()
  local summary = summarize(false)
  local choices = {}
  for _, name in ipairs(wezterm.mux.get_workspace_names()) do
    if not (exclude_current and name == current) then
      local mark = name == current and "* " or "  "
      local tabs = summary[name] and summary[name].tabs or 0
      table.insert(choices, { id = name, label = string.format("%s%s  (タブ%d)", mark, name, tabs) })
    end
  end
  return choices
end

local function switch_picker(window, pane)
  window:perform_action(
    act.InputSelector({
      title = "ワークスペースを切り替え",
      fuzzy = true,
      choices = workspace_choices(window, false),
      action = wezterm.action_callback(function(win, p, id)
        if id then
          win:perform_action(act.SwitchToWorkspace({ name = id }), p)
        end
      end),
    }),
    pane
  )
end

local function prompt_new_name(window, pane)
  local cwd_url = pane:get_current_working_dir()
  window:perform_action(
    act.PromptInputLine({
      description = "ワークスペース名:",
      action = wezterm.action_callback(function(win, p, line)
        if line and line ~= "" then
          win:perform_action(
            act.SwitchToWorkspace({ name = line, spawn = { cwd = cwd_url and cwd_url.file_path or nil } }),
            p
          )
        end
      end),
    }),
    pane
  )
end

local function new_picker(window, pane)
  local choices = { { id = INPUT_ID, label = "名前を入力して作成" } }
  local ok, stdout, stderr = wezterm.run_child_process({ "ghq", "list", "-p" })
  if ok then
    local home = os.getenv("HOME") or ""
    for path in stdout:gmatch("[^\n]+") do
      table.insert(choices, { id = path, label = string.format("%s  %s", basename(path), path:gsub("^" .. home, "~")) })
    end
  else
    wezterm.log_error("workspaces: ghq list failed: " .. tostring(stderr))
  end

  window:perform_action(
    act.InputSelector({
      title = "ワークスペースを作成(既存の名前なら切り替え)",
      fuzzy = true,
      choices = choices,
      action = wezterm.action_callback(function(win, p, id)
        if not id then
          return
        end
        if id == INPUT_ID then
          prompt_new_name(win, p)
        else
          win:perform_action(act.SwitchToWorkspace({ name = basename(id), spawn = { cwd = id } }), p)
        end
      end),
    }),
    pane
  )
end

local function close_workspace(window, name)
  -- MuxPaneにはLuaから閉じるメソッドが無いため、CLIで閉じる。
  -- GUIプロセス内から同期実行すると応答待ちが絡むので、投げっぱなしにする
  local cli = wezterm.executable_dir .. "/wezterm"
  for _, mux_win in ipairs(wezterm.mux.all_windows()) do
    if mux_win:get_workspace() == name then
      for _, tab in ipairs(mux_win:tabs()) do
        for _, p in ipairs(tab:panes()) do
          wezterm.background_child_process({ cli, "cli", "kill-pane", "--pane-id", tostring(p:pane_id()) })
        end
      end
    end
  end
  -- 保存ファイルが残ると、プラグインの一覧読み込み(ALT+l)で片付けたものが復活するため消す
  os.remove(sessions.STATE_DIR .. "wezterm_state_" .. sessions.escape_file_name(name) .. ".json")
  window:toast_notification("WezTerm", "ワークスペース「" .. name .. "」を片付けました", nil, 3000)
end

local function confirm_close(window, pane, name)
  local s = summarize(true)[name] or { tabs = 0, busy = 0 }
  local detail = string.format("タブ%d", s.tabs)
  if s.busy > 0 then
    detail = detail .. string.format("、処理中のClaude %d", s.busy)
  end
  window:perform_action(
    act.InputSelector({
      title = "ワークスペース「" .. name .. "」を片付けますか？",
      choices = {
        { id = "no", label = "やめる" },
        { id = "yes", label = string.format("閉じる: %s(%s)", name, detail) },
      },
      action = wezterm.action_callback(function(win, _, id)
        if id == "yes" then
          close_workspace(win, name)
        end
      end),
    }),
    pane
  )
end

local function cleanup_picker(window, pane)
  local choices = workspace_choices(window, true)
  if #choices == 0 then
    window:toast_notification("WezTerm", "片付けられるワークスペースがありません(今いるものは対象外)", nil, 3000)
    return
  end
  window:perform_action(
    act.InputSelector({
      title = "片付けるワークスペースを選択",
      fuzzy = true,
      choices = choices,
      action = wezterm.action_callback(function(win, p, id)
        if id then
          confirm_close(win, p, id)
        end
      end),
    }),
    pane
  )
end

function M.setup(config)
  config.keys = config.keys or {}
  table.insert(config.keys, { key = "n", mods = "LEADER", action = wezterm.action_callback(new_picker) })
  table.insert(config.keys, { key = "w", mods = "LEADER", action = wezterm.action_callback(switch_picker) })
  table.insert(config.keys, { key = "W", mods = "LEADER|SHIFT", action = wezterm.action_callback(cleanup_picker) })
end

return M
