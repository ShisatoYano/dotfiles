return {
  "lewis6991/gitsigns.nvim",
  config = function()
    require("gitsigns").setup({
      signs = {
        add = { text = "│" },
        change = { text = "│" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
      },
      current_line_blame = true, -- GitLensのような行末blame表示
      current_line_blame_opts = {
        delay = 300,
      },
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local opts = { buffer = bufnr }

        -- 変更箇所へのジャンプ
        vim.keymap.set("n", "]c", gs.next_hunk, vim.tbl_extend("force", opts, { desc = "Next git change" }))
        vim.keymap.set("n", "[c", gs.prev_hunk, vim.tbl_extend("force", opts, { desc = "Prev git change" }))

        -- 変更箇所のプレビュー(差分をポップアップ表示)
        vim.keymap.set("n", "<leader>hp", gs.preview_hunk, vim.tbl_extend("force", opts, { desc = "Preview hunk" }))

        -- 変更を元に戻す(その変更箇所だけUndo)
        vim.keymap.set("n", "<leader>hr", gs.reset_hunk, vim.tbl_extend("force", opts, { desc = "Reset hunk" }))

        -- ファイル全体の変更を元に戻す
        vim.keymap.set("n", "<leader>hR", gs.reset_buffer, vim.tbl_extend("force", opts, { desc = "Reset buffer" }))

        -- その行だけステージ/アンステージ
        vim.keymap.set("n", "<leader>hs", gs.stage_hunk, vim.tbl_extend("force", opts, { desc = "Stage hunk" }))
        vim.keymap.set("n", "<leader>hu", gs.undo_stage_hunk, vim.tbl_extend("force", opts, { desc = "Unstage hunk" }))

        -- インラインblameの表示切り替え
        vim.keymap.set("n", "<leader>hb", gs.toggle_current_line_blame, vim.tbl_extend("force", opts, { desc = "Toggle line blame" }))
      end,
    })
  end,
}
