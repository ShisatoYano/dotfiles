return {
  {
    "Mofiqul/dracula.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      -- ダークはDracula、ライトはSolarized Lightを使う
      local function apply_dark()
        vim.o.background = "dark"
        require("dracula").setup({
          transparent_bg = true, -- WezTermの背景透過を活かすため
        })
        vim.cmd.colorscheme("dracula")
      end

      local function apply_light()
        vim.o.background = "light"
        require("solarized").setup({
          variant = "winter", -- 標準的なSolarized配色
        })
        vim.cmd.colorscheme("solarized")
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
    "maxmx03/solarized.nvim",
    name = "solarized",
    lazy = true,
  },
}
