local M = {}

-- 汎用キーマップ(起動時に読み込まれる)
vim.keymap.set("n", "<leader>v", "<cmd>vsplit<CR>", { desc = "Split window vertically" })
vim.keymap.set("n", "<leader>s", "<cmd>split<CR>", { desc = "Split window horizontally" })
vim.keymap.set("n", "<leader>x", "<cmd>close<CR>", { desc = "Close current split" })
vim.keymap.set("n", "<leader>r", "<cmd>nohlsearch<CR><cmd>diffupdate<CR><cmd>redraw!<CR>", { desc = "Clear and redraw screen" })
vim.keymap.set("n", "<leader>gh", "<cmd>edit ~/dotfiles/docs/git-cheatsheet.md<CR>", { desc = "Open git cheatsheet" })
vim.keymap.set("n", "<leader>nh", "<cmd>edit ~/dotfiles/docs/nvim-cheatsheet.md<CR>", { desc = "Open nvim cheatsheet" })
vim.keymap.set("n", "<leader>wh", "<cmd>edit ~/dotfiles/docs/terminal-cheatsheet.md<CR>", { desc = "Open terminal cheatsheet" })
vim.keymap.set("n", "<leader>dh", "<cmd>edit ~/dotfiles/docs/docker-cheatsheet.md<CR>", { desc = "Open docker cheatsheet" })
vim.keymap.set("n", "<leader>vh", "<cmd>edit ~/dotfiles/docs/vimium-cheatsheet.md<CR>", { desc = "Open vimium cheatsheet" })
vim.keymap.set("n", "<leader>mh", "<cmd>edit ~/dotfiles/docs/nb-cheatsheet.md<CR>", { desc = "Open nb (memo) cheatsheet" })

-- LSPがバッファにアタッチされたときに呼ばれるキーマップ設定
function M.on_lsp_attach(args)
  local opts = { buffer = args.buf }
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
  vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
  vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
end

return M
