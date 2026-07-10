return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  config = function()
    require("nvim-autopairs").setup({})

    -- blink.cmpで関数を補完確定した際、自動で()まで入力する連携
    local ok, cmp_autopairs = pcall(require, "nvim-autopairs.completion.cmp")
    if ok then
      -- blink.cmp用の統合(blink.cmp側にも対応イベントがあるため、こちらで発火させる)
    end
  end,
}
