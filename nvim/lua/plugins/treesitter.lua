return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  config = function()
    local ts = require("nvim-treesitter")
    ts.setup()
    ts.install({ "cpp", "c", "python", "cmake", "yaml", "lua", "bash", "xml" })

    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "cpp", "c", "python", "cmake", "yaml", "lua", "bash", "xml" },
      callback = function()
        vim.treesitter.start()
      end,
    })
  end,
}
