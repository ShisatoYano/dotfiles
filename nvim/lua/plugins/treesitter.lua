return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  config = function()
    local ts = require("nvim-treesitter")
    ts.setup()
    -- markdown_inlineはfiletypeではないが、markdownが本文中のリンク・強調等を
    -- インジェクションで解釈するのに必要なため、インストール対象にだけ含める
    ts.install({ "cpp", "c", "python", "cmake", "yaml", "lua", "bash", "xml", "markdown", "markdown_inline", "json" })

    vim.api.nvim_create_autocmd("FileType", {
      -- .shのfiletypeはbashではなくshになるため、shも対象にしないと
      -- 従来のsh syntaxにフォールバックし、here-string(<<<)以降がヒアドキュメント扱いで崩れる
      pattern = { "cpp", "c", "python", "cmake", "yaml", "lua", "bash", "sh", "xml", "markdown", "json" },
      callback = function()
        vim.treesitter.start()
      end,
    })
  end,
}
