return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local api = require("nvim-tree.api")

    -- クリップボードの画像を、カーソル位置のディレクトリに直接保存する
    -- (img-clip.nvimは編集可能なバッファへの挿入を前提としているため、
    --  読み取り専用のツリーバッファではwl-pasteを直接使う)
    local function paste_image_here()
      local node = api.tree.get_node_under_cursor()
      if not node then
        return
      end
      local dir = node.type == "directory" and node.absolute_path or vim.fn.fnamemodify(node.absolute_path, ":h")

      vim.ui.input({ prompt = "ファイル名: ", default = os.date("%Y-%m-%d-%H-%M-%S") .. ".png" }, function(filename)
        if not filename or filename == "" then
          return
        end
        local target = dir .. "/" .. filename
        -- PNGはNULバイトを含むため、Luaの文字列として取り込む(vim.fn.system)と
        -- NULバイトが壊れる。シェルリダイレクトで直接ファイルへ書き出す
        os.execute("wl-paste --type image/png > " .. vim.fn.shellescape(target) .. " 2>/dev/null")

        if vim.fn.getfsize(target) <= 0 then
          vim.fn.delete(target)
          vim.notify("クリップボードに画像がありません", vim.log.levels.WARN)
          return
        end
        vim.notify("画像を保存しました: " .. target)
        api.tree.reload()
      end)
    end

    require("nvim-tree").setup({
      on_attach = function(bufnr)
        api.map.on_attach.default(bufnr)
        vim.keymap.set("n", "i", paste_image_here, { buffer = bufnr, desc = "Paste image from clipboard here" })
      end,
    })
    vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeFindFile<CR>", { desc = "Focus current file in tree" })
    vim.keymap.set("n", "<leader>E", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file tree" })
    -- ツリーを開いていなくても、ファイル操作(コピー/リネーム/削除等)のキー一覧をすぐ確認できるようにする
    -- ("<leader>e"は既存の完結したマッピングのため、prefixが被らないキーにする)
    vim.keymap.set("n", "<leader>k", function()
      local api = require("nvim-tree.api")
      api.tree.open()
      api.tree.toggle_help()
    end, { desc = "Open file tree and show its help" })
  end,
}
