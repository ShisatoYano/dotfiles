return {
  "rbong/vim-flog",
  dependencies = { "tpope/vim-fugitive" },
  cmd = { "Flog" },
  keys = {
    { "<leader>gl", "<cmd>Flog<CR>", desc = "Open git commit graph" },
  },
}
