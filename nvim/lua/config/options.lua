-- システムクリップボードと連携（コピペが自然にできるように）
vim.opt.clipboard = "unnamedplus"

-- インサートモードで jk を押すと即座にノーマルモードに戻れる
vim.keymap.set("i", "jk", "<Esc>", { desc = "Escape insert mode" })

-- 行番号を表示（IDE的な見た目に近づける）
vim.opt.number = true
vim.opt.relativenumber = true

-- カーソルがある行・列をハイライトする
vim.opt.cursorline = true
vim.opt.cursorcolumn = true

-- 長い行を折り返さない(コードは横スクロールで見る方が読みやすいため)
vim.opt.wrap = false
vim.opt.listchars = { extends = "…", precedes = "…", tab = "  " }
vim.opt.list = true

-- Tabキーでタブ文字ではなくスペースを挿入する(このリポジトリは2スペースインデント)
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2

-- CursorHoldの発火を実用的な速さにする(既定の4秒では下のchecktimeが遅すぎる)
vim.opt.updatetime = 500

-- 別プロセス(Claude Code、gitコマンド等)が書き換えたファイルを、開いているバッファに取り込む。
-- autoreadは「変更を検知したら読み直す」だけの設定で、検知のきっかけ(checktime)は自前で作る必要がある
-- (これがないとバッファに入り直すまで内容もgitsignsの差分表示も古いまま)
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "TermLeave" }, {
  callback = function()
    -- コマンドライン入力中のchecktimeは入力を妨げるため避ける
    if vim.fn.mode() ~= "c" then
      pcall(vim.cmd.checktime)
    end
  end,
})

-- 読み直しは黙って起きると混乱するので通知する(編集中のバッファは上書きされず警告が出る)
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  callback = function()
    vim.notify("外部で変更されたため再読み込みしました: " .. vim.fn.expand("<afile>:t"), vim.log.levels.WARN)
  end,
})

-- Markdownなど文章系のファイルだけ折り返しを有効にする
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true -- 単語の途中では折り返さない
  end,
})

-- カーソル位置の単語と一致する箇所を、ファイル種別(LSPの有無)に関わらずハイライトする
-- (カラースキーム適用時にハイライトグループがリセットされるため、ColorSchemeイベントで都度再設定する)
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "CursorWordMatch", { link = "IncSearch" })
  end,
})
vim.api.nvim_set_hl(0, "CursorWordMatch", { link = "IncSearch" })

local function highlight_cursor_word()
  if vim.w.cursor_word_match_id then
    pcall(vim.fn.matchdelete, vim.w.cursor_word_match_id)
    vim.w.cursor_word_match_id = nil
  end

  -- キーワード文字(英数字等)の上にいないときは対象外(空白/記号上でcwordを拾わないため)
  local char = vim.fn.getline("."):sub(vim.fn.col("."), vim.fn.col("."))
  if vim.fn.match(char, [[\k]]) == -1 then
    return
  end

  local cword = vim.fn.expand("<cword>")
  if cword == "" then
    return
  end

  local pattern = [[\<]] .. vim.fn.escape(cword, "\\/.*$^~[]") .. [[\>]]
  vim.w.cursor_word_match_id = vim.fn.matchadd("CursorWordMatch", pattern, -1)
end

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  callback = highlight_cursor_word,
})
