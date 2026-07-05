local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    lazyrepo,
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    {
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
    },
  },
  install = { colorscheme = { "habamax" } },
  checker = { enabled = false },
})
