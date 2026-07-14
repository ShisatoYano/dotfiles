-- システムクリップボードと連携（コピペが自然にできるように）
vim.opt.clipboard = "unnamedplus"

-- インサートモードで jk を押すと即座にノーマルモードに戻れる
vim.keymap.set("i", "jk", "<Esc>", { desc = "Escape insert mode" })

-- 行番号を表示（IDE的な見た目に近づける）
vim.opt.number = true
vim.opt.relativenumber = true

-- 長い行を折り返さない(コードは横スクロールで見る方が読みやすいため)
vim.opt.wrap = false
vim.opt.listchars = { extends = "…", precedes = "…", tab = "  " }
vim.opt.list = true

-- Tabキーでタブ文字ではなくスペースを挿入する(このリポジトリは2スペースインデント)
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2

-- Markdownなど文章系のファイルだけ折り返しを有効にする
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true -- 単語の途中では折り返さない
  end,
})
