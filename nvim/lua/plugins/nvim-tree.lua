return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("nvim-tree").setup()
    vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeFindFile<CR>", { desc = "Focus current file in tree" })
    vim.keymap.set("n", "<leader>E", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file tree" })
    -- ツリーを開いていなくても、ファイル操作(コピー/リネーム/削除等)のキー一覧をすぐ確認できるようにする
    -- ("<leader>e"は既存の完結したマッピングのため、prefixが被らないキーにする)
    vim.keymap.set("n", "<leader>k", function()
      local api = require("nvim-tree.api")
      api.tree.open()
      api.tree.toggle_help()
    end, { desc = "Open file tree and show its help" })
  end,
}
