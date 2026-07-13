return {
  {
    "loctvl842/monokai-pro.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      -- filterとtransparent_backgroundを同時に切り替えて再適用する
      local function apply(filter, transparent)
        require("monokai-pro.config").extend({ filter = filter, transparent_background = transparent })
        require("monokai-pro.theme").clear_cache()
        require("monokai-pro").load()

        if transparent then
          -- 透過時は背景越しに他アプリの明るい色が見えることがあり、
          -- 標準のコメント色(dimmed3相当)だと読みにくいので明るめに上書きする
          vim.api.nvim_set_hl(0, "Comment", { fg = "#9d9b9d", italic = true })
        end
      end

      require("monokai-pro").setup({
        filter = "pro",
        transparent_background = true, -- WezTermの背景透過を活かすため(ダークのみ)
      })
      apply("pro", true)

      local M = { is_dark = true }

      function M.toggle()
        if M.is_dark then
          apply("light", false)
        else
          apply("pro", true)
        end
        M.is_dark = not M.is_dark
      end

      vim.keymap.set("n", "<leader>t", M.toggle, { desc = "Toggle light/dark colorscheme" })
    end,
  },
  {
    -- 現在は未使用だが、今後のために起動時ロードはせずインストールだけ残す
    "projekt0n/github-nvim-theme",
    lazy = true,
  },
}
