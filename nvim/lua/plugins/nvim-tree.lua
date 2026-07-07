return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("nvim-tree").setup()
    vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeFindFile<CR>", { desc = "Focus current file in tree" })
    vim.keymap.set("n", "<leader>E", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file tree" })
  end,
}
