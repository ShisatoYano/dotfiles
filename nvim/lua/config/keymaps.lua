local M = {}

-- 汎用キーマップ(起動時に読み込まれる)
vim.keymap.set("n", "<leader>v", "<cmd>vsplit<CR>", { desc = "Split window vertically" })
vim.keymap.set("n", "<leader>s", "<cmd>split<CR>", { desc = "Split window horizontally" })
vim.keymap.set("n", "<leader>x", "<cmd>close<CR>", { desc = "Close current split" })
vim.keymap.set("n", "<leader>r", "<cmd>nohlsearch<CR><cmd>diffupdate<CR><cmd>redraw!<CR>", { desc = "Clear and redraw screen" })
vim.keymap.set("n", "<leader>gh", "<cmd>edit ~/dotfiles/docs/git-cheatsheet.md<CR>", { desc = "Open git cheatsheet" })

-- LSPがバッファにアタッチされたときに呼ばれるキーマップ設定
function M.on_lsp_attach(args)
  local opts = { buffer = args.buf }
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
  vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
  vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
end

return M
