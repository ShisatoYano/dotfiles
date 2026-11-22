local wezterm = require("wezterm")
local act = wezterm.action
local sessions = require("config.sessions")
local tab_title = require("config.tab_title")
local claude_cli = require("config.claude_cli")
local M = {}

local INPUT_ID = "__input__"

local function basename(path)
  return (path:gsub("/+$", ""):match("([^/]+)$")) or path
end

-- ワークスペースごとのタブ数(count_busyなら処理中・権限確認待ちのClaudeの数も)を集計する
local function summarize(count_busy)
  local summary = {}
  for _, mux_win in ipairs(wezterm.mux.all_windows()) do
    local name = mux_win:get_workspace()
    local s = summary[name] or { tabs = 0, busy = 0 }
    for _, tab in ipairs(mux_win:tabs()) do
      s.tabs = s.tabs + 1
      if count_busy then
        for _, p in ipairs(tab:panes()) do
          local claude = tab_title.claude_state(p:get_foreground_process_name(), p:get_title(), p:pane_id())
          if claude and (claude.state == "busy" or claude.state == "waiting") then
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

-- 起動中のClaude Codeセッション名を端末(tty)ごとに引く表を返す。
-- ccsession経由だと前面プロセスとClaude本体のpidが一致しないため、ttyで突き合わせる
local function claude_names_by_tty()
  local names = {}
  local name_by_pid, pids = {}, {}
  for _, a in ipairs(claude_cli.agents()) do
    if a.pid and a.name then
      name_by_pid[tostring(a.pid)] = a.name
      table.insert(pids, tostring(a.pid))
    end
  end
  if #pids == 0 then
    return names
  end
  local ps_ok, ps_out = wezterm.run_child_process({ "ps", "-o", "pid=,tty=", "-p", table.concat(pids, ",") })
  if ps_ok then
    for pid, tty in ps_out:gmatch("(%d+)%s+(%S+)") do
      if name_by_pid[pid] and tty ~= "?" then
        names["/dev/" .. tty] = name_by_pid[pid]
      end
    end
  end
  return names
end

local function pad_right(s, width)
  return s .. string.rep(" ", math.max(0, width - wezterm.column_width(s)))
end

-- ワークスペース行の下に、そのワークスペースのClaudeセッション行(状態・名前・見出し)を並べる
local function switch_choices(window)
  local names = claude_names_by_tty()
  local sessions_by_ws = {}
  local name_width = 0
  for _, mux_win in ipairs(wezterm.mux.all_windows()) do
    local ws = mux_win:get_workspace()
    sessions_by_ws[ws] = sessions_by_ws[ws] or {}
    for _, tab in ipairs(mux_win:tabs()) do
      for _, p in ipairs(tab:panes()) do
        local claude = tab_title.claude_state(p:get_foreground_process_name(), p:get_title(), p:pane_id())
        if claude then
          local name = names[p:get_tty_name() or ""] or ""
          name_width = math.max(name_width, wezterm.column_width(name))
          table.insert(sessions_by_ws[ws], { pane_id = p:pane_id(), claude = claude, name = name })
        end
      end
    end
  end

  local choices = {}
  for _, ws_choice in ipairs(workspace_choices(window, false)) do
    table.insert(choices, ws_choice)
    for _, s in ipairs(sessions_by_ws[ws_choice.id] or {}) do
      table.insert(choices, {
        id = "pane:" .. s.pane_id,
        label = string.format(
          "    %s %s  %s",
          tab_title.CLAUDE_STATUS_ICONS[s.claude.state],
          pad_right(s.name, name_width),
          s.claude.heading or ""
        ),
      })
    end
  end
  return choices
end

local function activate_pane(window, pane, pane_id)
  local target = wezterm.mux.get_pane(pane_id)
  if not target then
    return
  end
  local tab = target:tab()
  window:perform_action(act.SwitchToWorkspace({ name = tab:window():get_workspace() }), pane)
  tab:activate()
  target:activate()
end

local function switch_picker(window, pane)
  window:perform_action(
    act.InputSelector({
      title = "ワークスペース・セッションを切り替え",
      fuzzy = true,
      choices = switch_choices(window),
      action = wezterm.action_callback(function(win, p, id)
        if not id then
          return
        end
        local pane_id = id:match("^pane:(%d+)$")
        if pane_id then
          activate_pane(win, p, tonumber(pane_id))
        else
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
    detail = detail .. string.format("、処理中・待ちのClaude %d", s.busy)
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
