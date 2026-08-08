return {
  "akinsho/bufferline.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons", "famiu/bufdelete.nvim" },
  config = function()
    local options = {
      offsets = {
        {
          filetype = "NvimTree",
          text = "File Explorer",
          highlight = "Directory",
          separator = true,
        },
      },
      -- not display buffers which name is empty and is not modified on tab bar
      custom_filter = function (buf_number)
        local name = vim.api.nvim_buf_get_name(buf_number)
        local modified = vim.api.nvim_buf_get_option(buf_number, "modified")
        if name == "" and not modified then
          return false
        end
        return true
      end,
    }

    require("bufferline").setup({ options = options })

    -- When color scheme is switched to dark or light, tab bar's highlight is calculated again with options
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = function ()
        require("bufferline").setup({ options = options })
      end,
    })

    -- タブ間の移動
    vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<CR>", { desc = "Next buffer tab" })
    vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<CR>", { desc = "Prev buffer tab" })
    -- 今開いているタブだけ残して他を全部閉じる
    vim.keymap.set("n", "<leader>bo", "<cmd>BufferLineCloseOthers<CR>", { desc = "Close other buffers" })
    -- 今のタブを閉じる
    vim.keymap.set("n", "<leader>bd", "<cmd>Bdelete<CR>", { desc = "Close current buffer" })
  end,
}
