return {
  "mfussenegger/nvim-lint",
  config = function()
    local lint = require("lint")

    -- nvim-lintのlinters_by_ftは"*"のようなワイルドカードに対応していないため、
    -- ファイル種別に関わらずtyposを直接指定して実行する(コード/コメント/文章どれでもOK)
    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
      callback = function()
        lint.try_lint("typos")
      end,
    })
  end,
}
