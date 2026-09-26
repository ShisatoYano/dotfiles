return {
  "selimacerbas/markdown-preview.nvim",
  dependencies = { "selimacerbas/live-server.nvim" },
  ft = { "markdown" },
  config = function()
    require("markdown_preview").setup({
      instance_mode = "takeover",
      open_browser = true,
      default_theme = "dark",
    })
    vim.keymap.set("n", "<leader>mb", "<cmd>MarkdownPreview<CR>", { desc = "Open markdown preview in browser" })

    -- mdrollはKittyグラフィックスで描画するため、nvimの:terminalではなくWezTermのペインで開く
    vim.keymap.set("n", "<leader>mp", function()
      local pane = vim.env.WEZTERM_PANE
      local path = vim.api.nvim_buf_get_name(0)
      if not pane then
        return vim.notify("WezTerm外では使えません", vim.log.levels.WARN)
      end
      if path == "" then
        return vim.notify("ファイルに保存してから実行してください", vim.log.levels.WARN)
      end
      local res = vim.system({ "wezterm", "cli", "split-pane", "--right", "--", "mdroll", "--watch", path }):wait()
      if res.code ~= 0 then
        return vim.notify("mdrollペインを開けませんでした: " .. res.stderr, vim.log.levels.ERROR)
      end
      -- 分割すると新ペインにフォーカスが移るので、編集を続けられるようnvimに戻す
      vim.system({ "wezterm", "cli", "activate-pane", "--pane-id", pane })
    end, { desc = "Open markdown preview in WezTerm pane (mdroll)" })
  end,
}
