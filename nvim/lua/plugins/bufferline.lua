return {
  "akinsho/bufferline.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons", "famiu/bufdelete.nvim" },
  config = function()
    -- ダーク(solarized-osaka)は背景透過のためNormalのbgがnilになり、そこからタブの色を
    -- 算出するbufferlineでは選択中/非選択/余白が全て同じ透過背景になって見分けられない。
    -- 透過自体は活かしたいので、選択中のタブにだけ背景色とアンダーラインを明示する。
    -- (ライトのsolarizedはNormalにbgがあり算出結果で問題ないため、既定のままにする)
    local function dark_highlights()
      local ok, c = pcall(function()
        return require("solarized-osaka.colors").setup()
      end)
      if not ok then
        return {}
      end

      -- アンダーラインの色(sp)はbufferlineの既定ではTabLineSelの背景=Normalの背景色になり、
      -- 透過背景では見えなくなるため、インジケータの色を明示する
      local selected = { bg = c.bg_highlight, fg = c.base1, sp = c.blue, bold = true, italic = false }
      local inactive = { bg = "NONE", fg = c.base00 }
      -- 選択中のタブは背景を敷くので、そのタブ内の要素にも同じ背景・下線色を引き継がせる
      local on_selected = function(fg)
        return { bg = c.bg_highlight, fg = fg, sp = c.blue }
      end

      return {
        fill = { bg = "NONE" },
        background = inactive,
        buffer_visible = inactive,
        buffer_selected = selected,
        duplicate = inactive,
        duplicate_visible = inactive,
        duplicate_selected = vim.tbl_extend("force", selected, { italic = true }),
        modified = { bg = "NONE", fg = c.yellow },
        modified_visible = { bg = "NONE", fg = c.yellow },
        modified_selected = on_selected(c.yellow),
        separator = { bg = "NONE", fg = c.base02 },
        separator_visible = { bg = "NONE", fg = c.base02 },
        separator_selected = on_selected(c.base02),
        indicator_selected = on_selected(c.blue),
        offset_separator = { bg = "NONE", fg = c.base02 },
        tab = inactive,
        tab_selected = on_selected(c.blue),
        tab_separator = { bg = "NONE", fg = c.base02 },
        tab_separator_selected = on_selected(c.base02),
      }
    end

    local options = {
      -- 既定(themable=true)ではハイライトがdefault指定で設定され、一度定義された
      -- BufferLine*グループがテーマ切り替え後も上書きされずダークの色のまま残るため、
      -- 強制的に設定し直させる(ハイライトはこのファイルで管理するので副作用はない)
      themable = false,
      -- 閉じる操作はキーマップ(<leader>bd)で行うため、タブ上の×アイコンは表示しない
      show_buffer_close_icons = false,
      show_close_icon = false,
      -- 選択中のタブを下線で示す(透過背景でも位置が分かるように)
      indicator = { style = "underline" },
      offsets = {
        {
          filetype = "NvimTree",
          text = "File Explorer",
          highlight = "Directory",
          separator = true,
        },
      },
      -- not display buffers which name is empty and is not modified on tab bar
      custom_filter = function (buf_number)
        local name = vim.api.nvim_buf_get_name(buf_number)
        local modified = vim.api.nvim_buf_get_option(buf_number, "modified")
        if name == "" and not modified then
          return false
        end
        return true
      end,
    }

    local function setup()
      require("bufferline").setup({
        options = options,
        highlights = vim.o.background == "dark" and dark_highlights() or {},
      })
    end

    setup()

    -- When color scheme is switched to dark or light, tab bar's highlight is calculated again with options
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = setup,
    })

    -- タブ間の移動
    vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<CR>", { desc = "Next buffer tab" })
    vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<CR>", { desc = "Prev buffer tab" })
    -- 今開いているタブだけ残して他を全部閉じる
    vim.keymap.set("n", "<leader>bo", "<cmd>BufferLineCloseOthers<CR>", { desc = "Close other buffers" })
    -- 今のタブを閉じる
    vim.keymap.set("n", "<leader>bd", "<cmd>Bdelete<CR>", { desc = "Close current buffer" })
  end,
}
