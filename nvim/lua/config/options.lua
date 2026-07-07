-- システムクリップボードと連携（コピペが自然にできるように）
vim.opt.clipboard = "unnamedplus"

-- インサートモードで jk を押すと即座にノーマルモードに戻れる
vim.keymap.set("i", "jk", "<Esc>", { desc = "Escape insert mode" })

-- 行番号を表示（IDE的な見た目に近づける）
vim.opt.number = true
vim.opt.relativenumber = true
