local wezterm = require("wezterm")
local M = {}

local function version_key(path)
  local major, minor, patch = path:match("/v(%d+)%.(%d+)%.(%d+)/")
  return (tonumber(major) or 0) * 1e8 + (tonumber(minor) or 0) * 1e4 + (tonumber(patch) or 0)
end

-- GUIから起動したWezTermのPATHにはnvmのbinが無いため、nvm配下の最新nodeのものを探してからPATHに頼る。
-- globは文字列順(v9がv24より後)なので、バージョン番号で比べる
function M.executable()
  local best
  for _, path in ipairs(wezterm.glob(wezterm.home_dir .. "/.nvm/versions/node/*/bin/claude")) do
    if not best or version_key(path) > version_key(best) then
      best = path
    end
  end
  return best or "claude"
end

-- 起動中のClaude Codeセッションの一覧(claude agents --json)を返す。失敗時は空
function M.agents()
  local ok, stdout, stderr = wezterm.run_child_process({ M.executable(), "agents", "--json" })
  if not ok then
    wezterm.log_error("claude_cli: claude agents failed: " .. tostring(stderr))
    return {}
  end
  local parsed_ok, agents = pcall(wezterm.json_parse, stdout)
  if not parsed_ok or type(agents) ~= "table" then
    return {}
  end
  return agents
end

return M
