return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    -- ファイル種別ごとの言語バージョンをステータスバーに表示する
    -- (毎回コマンドを実行すると重いため、種別ごとに1回だけ実行してキャッシュする)
    local version_cache = {}
    local version_commands = {
      python = { "python3", "--version" },
      lua = { "lua", "-v" },
      sh = { "bash", "--version" },
      bash = { "bash", "--version" },
      javascript = { "node", "--version" },
      typescript = { "node", "--version" },
      go = { "go", "version" },
      rust = { "rustc", "--version" },
      c = { "gcc", "--version" },
      cpp = { "gcc", "--version" },
    }

    local function language_version()
      local ft = vim.bo.filetype
      if ft == "" then
        return ""
      end
      if version_cache[ft] ~= nil then
        return version_cache[ft]
      end

      local cmd = version_commands[ft]
      if not cmd then
        version_cache[ft] = ""
        return ""
      end

      local ok, result = pcall(vim.fn.system, cmd)
      if not ok or vim.v.shell_error ~= 0 then
        version_cache[ft] = ""
        return ""
      end

      local version = result:match("(%d+%.%d+[%.%d]*)")
      version_cache[ft] = version and (ft .. " " .. version) or ""
      return version_cache[ft]
    end

    require("lualine").setup({
      options = {
        theme = "auto",
        globalstatus = true, -- 分割ウィンドウがあっても1本だけ画面下部に表示
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff" },
        lualine_c = { "filename" },
        lualine_x = { "diagnostics", language_version, "filetype", "encoding" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    })
  end,
}
