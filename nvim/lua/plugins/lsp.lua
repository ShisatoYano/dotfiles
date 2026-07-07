return {
  "neovim/nvim-lspconfig",
  dependencies = { "saghen/blink.cmp" },
  config = function()
    -- blink.cmpの補完機能をLSPサーバーに伝える
    vim.lsp.config("*", {
      capabilities = require("blink.cmp").get_lsp_capabilities(),
    })

    vim.lsp.enable({ "clangd", "pyright", "lua_ls" })

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        require("config.keymaps").on_lsp_attach(args)
      end,
    })
  end,
}
