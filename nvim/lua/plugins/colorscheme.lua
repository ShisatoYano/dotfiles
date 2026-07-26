return {
  {
    "Mofiqul/dracula.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      -- ダークはDracula、ライトはMonokai Pro (Light)の方が見やすいため、
      -- ライトのときだけmonokai-pro.nvim(lazyインストール済み)を使う
      local function apply_dark()
        vim.o.background = "dark"
        require("dracula").setup({
          transparent_bg = true, -- WezTermの背景透過を活かすため
        })
        vim.cmd.colorscheme("dracula")
      end

      local function apply_light()
        vim.o.background = "light"
        require("monokai-pro.config").extend({
          filter = "light",
          transparent_background = false,
          background_clear = { "toggleterm", "telescope", "renamer", "notify" },
        })
        require("monokai-pro.theme").clear_cache()
        require("monokai-pro").load()
      end

      apply_dark()

      local M = { is_dark = true }

      function M.toggle()
        if M.is_dark then
          apply_light()
        else
          apply_dark()
        end
        M.is_dark = not M.is_dark
      end

      vim.keymap.set("n", "<leader>t", M.toggle, { desc = "Toggle light/dark colorscheme" })
    end,
  },
  {
    -- ライトテーマとして使用(初回requireでlazy.nvimが自動ロードする)
    "loctvl842/monokai-pro.nvim",
    lazy = true,
  },
  {
    -- 現在は未使用だが、今後のために起動時ロードはせずインストールだけ残す
    "projekt0n/github-nvim-theme",
    lazy = true,
  },
  {
    -- 現在は未使用だが、今後のために起動時ロードはせずインストールだけ残す
    "folke/tokyonight.nvim",
    lazy = true,
  },
}
