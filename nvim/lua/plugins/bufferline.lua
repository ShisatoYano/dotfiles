return {
  "akinsho/bufferline.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons", "famiu/bufdelete.nvim" },
  config = function()
    require("bufferline").setup({
      options = {
        offsets = {
          {
            filetype = "NvimTree",
            text = "File Explorer",
            highlight = "Directory",
            separator = true,
          },
        },
        -- 名前が空で未編集の(=中身が空の)バッファはタブに表示しない
        custom_filter = function(buf_number)
          local name = vim.api.nvim_buf_get_name(buf_number)
          local modified = vim.api.nvim_buf_get_option(buf_number, "modified")
          if name == "" and not modified then
            return false
          end
          return true
        end,
      },
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
