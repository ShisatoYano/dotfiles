return {
  {
    "loctvl842/monokai-pro.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("monokai-pro").setup()
    end,
  },
  {
    "projekt0n/github-nvim-theme",
    lazy = false,
    priority = 1000,
    config = function()
      require("github-theme").setup()
    end,
  },
  {
    -- テーマ切り替え用のダミー要素(依存プラグインが読み込まれた後に実行するため)
    "loctvl842/monokai-pro.nvim",
    name = "theme-toggle",
    lazy = false,
    priority = 900,
    config = function()
      vim.cmd("colorscheme monokai-pro")

      local M = { is_dark = true }

      function M.toggle()
        if M.is_dark then
          vim.cmd("colorscheme github_light")
        else
          vim.cmd("colorscheme monokai-pro")
        end
        M.is_dark = not M.is_dark
      end

      vim.keymap.set("n", "<leader>t", M.toggle, { desc = "Toggle light/dark colorscheme" })
    end,
  },
}
