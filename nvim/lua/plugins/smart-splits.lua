return {
  "mrjones2014/smart-splits.nvim",
  lazy = false,
  opts = {
    ignored_buftypes = { "nofile", "quickfix", "prompt" },
    ignored_filetypes = { "NvimTree" },
  },
  keys = {
    { "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "Move to left split/pane" },
    { "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "Move to below split/pane" },
    { "<C-k>", function() require("smart-splits").move_cursor_up() end, desc = "Move to above split/pane" },
    { "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move to right split/pane" },
    { "<A-h>", function() require("smart-splits").resize_left() end, desc = "Resize split left" },
    { "<A-j>", function() require("smart-splits").resize_down() end, desc = "Resize split down" },
    { "<A-k>", function() require("smart-splits").resize_up() end, desc = "Resize split up" },
    { "<A-l>", function() require("smart-splits").resize_right() end, desc = "Resize split right" },
  },
}
