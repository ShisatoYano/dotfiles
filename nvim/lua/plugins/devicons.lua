return {
  "nvim-tree/nvim-web-devicons",
  opts = {
    override_by_extension = {
      -- 既定の色(#4D5A5E)は塗りつぶしグリフのため、透過背景のダークテーマでは背景が欠けたように見える
      sh = { icon = "\u{e795}", color = "#89E051", cterm_color = "113", name = "Sh" },
    },
  },
}
