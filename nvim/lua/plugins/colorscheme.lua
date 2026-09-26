return {
  {
    "craftzdog/solarized-osaka.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      -- ダークはSolarized Osaka、ライトはSolarized Lightを使う
      local function apply_dark()
        vim.cmd("highlight clear")
        vim.o.background = "dark"
        require("solarized-osaka").setup({
          transparent = true, -- WezTermの背景透過を活かすため
        })
        vim.cmd.colorscheme("solarized-osaka")
      end

      local function apply_light()
        vim.cmd("highlight clear")
        vim.o.background = "light"
        require("solarized").setup({
          variant = "winter", -- 標準的なSolarized配色
        })
        vim.cmd.colorscheme("solarized")
      end

      -- ライト/ダークの状態はWezTerm(config/theme.lua)と共有するファイルに置き、
      -- どちらでトグルしても監視経由で両方(とClaude Code)が追従するようにする
      local state_file = vim.fn.expand("~/.local/state/theme-mode")
      local state_dir = vim.fs.dirname(state_file)
      local current

      local function read_mode()
        local ok, lines = pcall(vim.fn.readfile, state_file)
        return (ok and lines[1] == "light") and "light" or "dark"
      end

      local function sync()
        local mode = read_mode()
        if mode == current then
          return -- 自分の書き込みやWezTerm側の書き込みで複数回イベントが来ても再適用しない
        end
        current = mode
        if mode == "light" then
          apply_light()
        else
          apply_dark()
        end
      end

      sync()

      vim.fn.mkdir(state_dir, "p")
      -- ファイル単体ではなくディレクトリを監視し、置き換え(rename)で書かれても監視が外れないようにする
      local watcher = vim.uv.new_fs_event()
      watcher:start(state_dir, {}, vim.schedule_wrap(function(err, filename)
        if not err and filename == vim.fs.basename(state_file) then
          sync()
        end
      end))

      vim.keymap.set("n", "<leader>t", function()
        vim.fn.writefile({ current == "dark" and "light" or "dark" }, state_file)
      end, { desc = "Toggle light/dark colorscheme (shared with WezTerm/Claude)" })
    end,
  },
  {
    -- ライトテーマとして使用(初回requireでlazy.nvimが自動ロードする)
    "maxmx03/solarized.nvim",
    name = "solarized",
    lazy = true,
  },
}
