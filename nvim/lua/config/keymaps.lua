local M = {}

-- LSPがバッファにアタッチされたときに呼ばれるキーマップ設定
function M.on_lsp_attach(args)
  local opts = { buffer = args.buf }
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
  vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
  vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
end

return M
