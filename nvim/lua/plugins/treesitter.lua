return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  config = function()
    local ts = require("nvim-treesitter")
    ts.setup()
    ts.install({ "cpp", "c", "python", "cmake", "yaml", "lua", "bash", "xml" })

    vim.api.nvim_create_autocmd("FileType", {
      -- .shのfiletypeはbashではなくshになるため、shも対象にしないと
      -- 従来のsh syntaxにフォールバックし、here-string(<<<)以降がヒアドキュメント扱いで崩れる
      pattern = { "cpp", "c", "python", "cmake", "yaml", "lua", "bash", "sh", "xml" },
      callback = function()
        vim.treesitter.start()
      end,
    })
  end,
}
