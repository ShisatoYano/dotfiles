return {
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    local builtin = require("telescope.builtin")
    vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
    vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Grep in project" })
    vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "List open buffers" })
    vim.keymap.set("n", "<leader>fd", builtin.diagnostics, { desc = "List diagnostics (errors/warnings)" })
  end,
}
