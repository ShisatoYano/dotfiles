vim.g.mapleader = vim.api.nvim_replace_termcodes("<space>", true, true, true)

-- leaderキー単体(未確定のシーケンス)が来た場合に、スペース本来の意味(1文字右へ移動)へ
-- フォールバックしないようにする
vim.keymap.set({ "n", "v" }, "<space>", "<nop>", { silent = true })

require("config.options")
require("config.keymaps")
require("config.lazy")
