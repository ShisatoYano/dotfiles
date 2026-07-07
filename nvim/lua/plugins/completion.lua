return {
  "saghen/blink.cmp",
  version = "1.*",
  opts = {
    keymap = {
      preset = "default",
      ["<CR>"] = { "select_and_accept", "fallback" },
    },
    completion = {
      documentation = { auto_show = true },
      list = {
        selection = {
          preselect = true,
          auto_insert = false,
        },
      },
    },
    sources = {
      default = { "lsp", "path", "buffer" },
    },
  },
}
