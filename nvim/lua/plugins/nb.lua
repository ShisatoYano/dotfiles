return {
  "mozumasu/nb.nvim",
  dependencies = { "folke/snacks.nvim" },
  lazy = false,
  opts = {
    -- upstream未設定ならpushは行われずローカルcommitのみ実行されるため、保存して閉じた時点で自動コミットする
    autosync = true,
  },
  keys = {
    { "<leader>np", function() require("nb").pick() end, desc = "nb: ノートを検索" },
    { "<leader>ng", function() require("nb").grep() end, desc = "nb: ノート内容をgrep" },
    { "<leader>na", function() require("nb").add() end, desc = "nb: ノート作成" },
    { "<leader>nA", function() require("nb").add_select() end, desc = "nb: notebookを選んでノート作成" },
    { "<leader>ni", function() require("nb").import_image() end, desc = "nb: 画像をインポート" },
    { "<leader>nl", function() require("nb").link() end, desc = "nb: ノート/画像へのリンク挿入" },
    { "<leader>nm", function() require("nb").move() end, desc = "nb: 別notebookへ移動" },
    { "<leader>nM", function() require("nb").adopt_buffer() end, desc = "nb: 現在のバッファをnotebookに取り込む" },
  },
}
