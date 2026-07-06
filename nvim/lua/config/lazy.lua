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
    {
      "mason-org/mason.nvim",
      config = function()
        require("mason").setup()
      end,
    },
    {
      "mason-org/mason-lspconfig.nvim",
      dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
      config = function()
        require("mason-lspconfig").setup({
          ensure_installed = { "clangd", "pyright", "lua_ls" },
        })
      end,
    },
    {
      "neovim/nvim-lspconfig",
      config = function()
        vim.lsp.enable({ "clangd", "pyright", "lua_ls" })

	-- LSPが有効化されたバッファで自動補完を有効にする
	vim.api.nvim_create_autocmd("LspAttach", {
          callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if client and client:supports_method("textDocument/completion") then
              vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
            end
          end,
        })
      end,
    },
  },
  install = { colorscheme = { "habamax" } },
  checker = { enabled = false },
})
