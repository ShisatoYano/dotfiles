return {
  "selimacerbas/markdown-preview.nvim",
  dependencies = { "selimacerbas/live-server.nvim" },
  ft = { "markdown" },
  config = function()
    require("markdown_preview").setup({
      instance_mode = "takeover",
      open_browser = true,
      default_theme = "dark",
    })
    vim.keymap.set("n", "<leader>mp", "<cmd>MarkdownPreview<CR>", { desc = "Open markdown preview" })
  end,
}
