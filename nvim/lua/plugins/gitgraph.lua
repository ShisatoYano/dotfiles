return {
  "isakbm/gitgraph.nvim",
  dependencies = { "sindrets/diffview.nvim" },
  ---@type I.GGConfig
  opts = {
    hooks = {
      -- コミットの上でEnter: そのコミットの差分をDiffviewで開く
      on_select_commit = function(commit)
        vim.cmd(":DiffviewOpen " .. commit.hash .. "^!")
      end,
      -- ビジュアルモードで範囲選択してEnter: 2つのコミット間の差分を開く
      on_select_range_commit = function(from, to)
        vim.cmd(":DiffviewOpen " .. from.hash .. "~1.." .. to.hash)
      end,
    },
  },
  keys = {
    {
      "<leader>gl",
      function()
        require("gitgraph").draw({}, { all = true, max_count = 5000 })
      end,
      desc = "Open git commit graph",
    },
  },
}
