return {
  "3rd/image.nvim",
  build = false, -- magick_cliプロセッサを使うのでビルド不要
  opts = {
    -- WezTermはkitty protocolを完全サポートしていないため、Sixelを使う
    backend = "sixel",
    processor = "magick_cli",
  },
}
