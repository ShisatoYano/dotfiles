local wezterm = require("wezterm")
local sessions_wrapper = require("config.sessions")
local M = {}

local SCRIPT = wezterm.home_dir .. "/dotfiles/scripts/wezterm-worktree.sh"
local WORKTREES_ROOT = wezterm.home_dir .. "/worktrees"

local function run(args)
  local ok, stdout, stderr = wezterm.run_child_process(args)
  return ok, stdout, stderr
end

-- workspace名/ディレクトリ名として安全に使えるよう、目的名からパス不可な文字だけ落とす
-- (日本語などはそのまま活かし、一覧・ステータスバーでの視認性を優先する)
local function sanitize_name(name)
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  name = name:gsub("[/%z\1-\31]", "_")
  return name
end

local function basename(path)
  return (path:gsub("/$", ""):match("([^/]+)$")) or path
end

local function shell_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function repo_root_for_pane(pane)
  local ok, cwd_url = pcall(function()
    return pane:get_current_working_dir()
  end)
  local cwd = ok and cwd_url and cwd_url.file_path
  if not cwd then
    return nil
  end
  local ok2, out = run({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })
  if not ok2 then
    return nil
  end
  return (out:gsub("%s+$", ""))
end

local function list_workspaces()
  local ok, out = run({ SCRIPT, "list" })
  if not ok then
    return {}
  end
  local ok2, data = pcall(wezterm.json_parse, out)
  if not ok2 or type(data) ~= "table" then
    return {}
  end
  return data
end

-- Yes/Noの簡易確認ダイアログ。作成前の未コミット警告と削除前の確認で共用する。
-- on_yesには、この確認ダイアログ自身が渡してくるpaneを引き継いで渡す
-- (呼び出し元の古いpane参照を使い回さないため)
local function confirm(window, pane, title, description, on_yes)
  window:perform_action(
    wezterm.action.InputSelector({
      title = title,
      description = description,
      choices = { { id = "yes", label = "はい" }, { id = "no", label = "いいえ" } },
      action = wezterm.action_callback(function(_, inner_pane, id)
        if id == "yes" then
          on_yes(inner_pane)
        end
      end),
    }),
    pane
  )
end

local function do_create(window, pane, repo_root, purpose)
  local name = sanitize_name(purpose)
  local repo_name = basename(repo_root)
  local worktree_path = WORKTREES_ROOT .. "/" .. name .. "/" .. repo_name
  local shell = os.getenv("SHELL") or "/bin/bash"

  -- 作成後、成功していればそのままworktreeにcdしてシェルに入る。
  -- 失敗した場合はエラーメッセージがペインに残ったまま元のディレクトリでシェルに入る
  local cmd = string.format(
    "%s create %s %s %s %s && cd %s; exec %s",
    shell_quote(SCRIPT),
    shell_quote(repo_root),
    shell_quote(worktree_path),
    shell_quote(name),
    shell_quote(purpose),
    shell_quote(worktree_path),
    shell_quote(shell)
  )

  -- mux.spawn_window+mux.set_active_workspaceは(wezterm-sessionsのfork_stateと
  -- 同じ組み合わせだが)guiフロントエンドが別OSウィンドウを自動で開いてしまい、
  -- 「ウィンドウは常に1つ」という要件に合わなかったため、今のウィンドウをそのまま
  -- 新workspaceへ切り替えるシンプルな形に戻す
  window:perform_action(
    wezterm.action.SwitchToWorkspace({
      name = name,
      spawn = {
        cwd = repo_root,
        args = { shell, "-c", cmd },
      },
    }),
    pane
  )
end

function M.create_workspace()
  return wezterm.action_callback(function(window, pane)
    local repo_root = repo_root_for_pane(pane)
    if not repo_root then
      window:toast_notification("Worktree Workspace", "gitリポジトリ内で実行してください", nil, 4000, "normal")
      return
    end

    local function prompt_purpose(p)
      window:perform_action(
        wezterm.action.PromptInputLine({
          description = "workspaceの目的を入力:",
          action = wezterm.action_callback(function(_, inner_pane, purpose)
            if not purpose or purpose == "" then
              return
            end
            do_create(window, inner_pane, repo_root, purpose)
          end),
        }),
        p
      )
    end

    local is_clean = run({ SCRIPT, "check-dirty", repo_root })
    if not is_clean then
      confirm(
        window,
        pane,
        "未コミットの変更があります",
        "現在の変更は新しいworktreeには引き継がれません。続行しますか?",
        prompt_purpose
      )
    else
      prompt_purpose(pane)
    end
  end)
end

-- workspaceに属する全paneを閉じる。worktree実体を消しても、それを表示していた
-- タブ/ウィンドウ自体は残ってしまい、切り替え一覧に「worktree管理外」として
-- 出続けてしまうため、削除時にペインごと片付ける
local function close_workspace_panes(name)
  local ok, windows = pcall(wezterm.mux.all_windows)
  if not ok or not windows then
    return
  end
  for _, mux_win in ipairs(windows) do
    if mux_win:get_workspace() == name then
      for _, tab in ipairs(mux_win:tabs()) do
        for _, p in ipairs(tab:panes()) do
          run({ "wezterm", "cli", "kill-pane", "--pane-id", tostring(p:pane_id()) })
        end
      end
    end
  end
end

function M.delete_workspace()
  return wezterm.action_callback(function(window, pane)
    local entries = list_workspaces()
    if #entries == 0 then
      window:toast_notification("Worktree Workspace", "登録されているworkspaceがありません", nil, 4000, "normal")
      return
    end

    local choices = {}
    for _, e in ipairs(entries) do
      table.insert(choices, {
        id = e.name,
        label = string.format("%s  (%s, %s)", e.name, e.purpose, e.current_branch),
      })
    end

    window:perform_action(
      wezterm.action.InputSelector({
        title = "削除するworkspaceを選択",
        fuzzy = true,
        choices = choices,
        action = wezterm.action_callback(function(_, inner_pane, id)
          if not id then
            return
          end
          confirm(window, inner_pane, "本当に削除しますか: " .. id, "worktreeとregistryから削除します", function()
            local ok, _, stderr = run({ SCRIPT, "remove", id })
            if ok then
              local file_path = sessions_wrapper.STATE_DIR
                .. "wezterm_state_"
                .. sessions_wrapper.escape_file_name(id)
                .. ".json"
              os.remove(file_path)
              -- 削除中のworkspaceが今アクティブな場合、ここでこのウィンドウ自体が
              -- 閉じることがあるため、通知を先に出してからペインを閉じる
              window:toast_notification("Worktree Workspace", "削除しました: " .. id, nil, 4000, "normal")
              close_workspace_panes(id)
            else
              window:toast_notification("Worktree Workspace", "削除に失敗しました: " .. (stderr or ""), nil, 6000, "normal")
            end
          end)
        end),
      }),
      pane
    )
  end)
end

function M.switch_workspace()
  return wezterm.action_callback(function(window, pane)
    local entries = list_workspaces()
    local registered = {}
    local worktree_paths = {}
    for _, e in ipairs(entries) do
      registered[e.name] = true
      worktree_paths[e.name] = e.worktree_path
    end

    local active = window:active_workspace()
    local choices = {}
    for _, e in ipairs(entries) do
      local marker = (e.name == active) and "* " or "  "
      table.insert(choices, {
        id = e.name,
        label = string.format("%s%s  (%s, %s)", marker, e.name, e.purpose, e.current_branch),
      })
    end

    -- worktreeとして作っていない既存のworkspace(defaultなど)も
    -- 切り替え先として選べないと「元の場所に戻れない」ことになるため、mux側の
    -- 一覧からregistry未登録のものを拾って混ぜる
    local ok, mux_names = pcall(wezterm.mux.get_workspace_names)
    if ok and mux_names then
      for _, name in ipairs(mux_names) do
        if not registered[name] then
          local marker = (name == active) and "* " or "  "
          table.insert(choices, {
            id = name,
            label = string.format("%s%s  (worktree管理外)", marker, name),
          })
        end
      end
    end

    if #choices == 0 then
      window:toast_notification("Worktree Workspace", "切り替え可能なworkspaceがありません", nil, 4000, "normal")
      return
    end

    window:perform_action(
      wezterm.action.InputSelector({
        title = "切り替え先のworkspaceを選択",
        fuzzy = true,
        choices = choices,
        action = wezterm.action_callback(function(_, inner_pane, id)
          if not id then
            return
          end
          -- 以前はここでsessions_plugin.restore_state(window)を呼び、WezTerm再起動後に
          -- 前回のタブ配置を自動復元しようとしていたが、switch_workspace実行のたびに
          -- タブが増殖する不具合(defaultなど他workspaceの保存済みタブが混ざる)の原因に
          -- なったため廃止した。単純にworkspaceを切り替えるだけにする。
          -- 再起動後に前回のレイアウトを戻したい場合は、wezterm-sessions標準の
          -- ALT+l(一覧から読み込み)/ALT+r(復元)を手動で使う
          --
          -- spawnにworktreeのパスを渡しておく。既にmux上に当該workspaceが存在する
          -- 場合はspawnは無視されて単純にそちらへ切り替わるだけだが、WezTerm再起動後で
          -- workspaceがまだ存在しない場合は、ここで指定したcwdで新規に開かれるため、
          -- worktree管理外(defaultなど)ではないworkspace_pathが無い場合はcwdを省略する
          local worktree_path = worktree_paths[id]
          window:perform_action(
            wezterm.action.SwitchToWorkspace({
              name = id,
              spawn = worktree_path and { cwd = worktree_path } or nil,
            }),
            inner_pane
          )
        end),
      }),
      pane
    )
  end)
end

-- ステータスバー用: アクティブworkspaceの目的名+現在ブランチを毎秒シェルを叩かず
-- 数秒おきにキャッシュ更新する(update-right-statusは高頻度で呼ばれるため)。
-- キャッシュはモジュールローカル変数ではなくwezterm.GLOBAL(config reloadを跨いで残る領域)に
-- 置く。automatically_reload_config=trueで頻繁にreloadされる環境だと、モジュールローカル変数は
-- reloadのたびに別インスタンスになってしまい、新旧インスタンスの値がちらつく原因になるため。
local function refresh_badge(window)
  local now = os.time()
  local active = window:active_workspace()
  if active == wezterm.GLOBAL.wt_badge_workspace and (now - (wezterm.GLOBAL.wt_badge_refreshed_at or 0)) < 5 then
    return
  end
  wezterm.GLOBAL.wt_badge_refreshed_at = now
  wezterm.GLOBAL.wt_badge_workspace = active

  local text = ""
  for _, e in ipairs(list_workspaces()) do
    if e.name == active then
      text = string.format("%s [%s]", e.purpose, e.current_branch)
      break
    end
  end
  wezterm.GLOBAL.wt_badge_text = text
end

-- config reloadのたびにLuaインタプリタ状態は作り直され、古いreloadで登録したwezterm.onは
-- 自然に破棄されるため、多重登録を気にして登録をガードする必要はない
-- (むしろガードすると、reload後もrefresh_badgeが最初の版のまま固定されてしまう)
wezterm.on("update-status", function(window, _)
  refresh_badge(window)
end)

function M.badge()
  return wezterm.GLOBAL.wt_badge_text or ""
end

function M.setup(config)
  config.keys = config.keys or {}
  table.insert(config.keys, {
    key = "q",
    mods = "CTRL",
    action = wezterm.action.ActivateKeyTable({
      name = "worktree_workspace",
      timeout_milliseconds = 2000,
      -- one_shot=trueだとwindow:active_key_table()に反映されず、resize_pane同様に
      -- ステータスバーへ表示できなかったため、resize_pane(one_shot=false)に合わせる。
      -- 1キーで抜ける挙動は各アクション末尾のPopKeyTableで担保する
      one_shot = false,
    }),
  })

  config.key_tables = config.key_tables or {}
  config.key_tables.worktree_workspace = {
    { key = "n", action = wezterm.action.Multiple({ M.create_workspace(), wezterm.action.PopKeyTable }) },
    { key = "d", action = wezterm.action.Multiple({ M.delete_workspace(), wezterm.action.PopKeyTable }) },
    { key = "g", action = wezterm.action.Multiple({ M.switch_workspace(), wezterm.action.PopKeyTable }) },
  }
end

return M
