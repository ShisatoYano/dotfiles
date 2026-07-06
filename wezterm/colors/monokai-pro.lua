-- colors.lua - Monokai Pro Theme Module for WezTerm
-- Based on loctvl842/monokai-pro.nvim

local wezterm = require("wezterm")
local module = {}

-- Helper function to create a theme variant
local function create_theme(name, palette)
  return {
    -- Cursor colors
    cursor_bg = palette.text,
    cursor_fg = palette.background,
    cursor_border = palette.text,

    -- Selection colors
    selection_fg = palette.background,
    selection_bg = palette.dimmed1,

    -- Terminal colors
    ansi = {
      palette.dark1,      -- black
      palette.accent1,    -- red
      palette.accent4,    -- green
      palette.accent3,    -- yellow
      palette.accent2,    -- blue
      palette.accent6,    -- magenta
      palette.accent5,    -- cyan
      palette.text,       -- white
    },
    brights = {
      palette.dimmed3,    -- bright black
      palette.accent1,    -- bright red
      palette.accent4,    -- bright green
      palette.accent3,    -- bright yellow
      palette.accent2,    -- bright blue
      palette.accent6,    -- bright magenta
      palette.accent5,    -- bright cyan
      palette.text,       -- bright white
    },

    -- Main window colors
    foreground = palette.text,
    background = palette.background,

    -- Tab bar colors
    tab_bar = {
      background = palette.dark1,
      
      active_tab = {
        bg_color = palette.background,
        fg_color = palette.accent3,
        intensity = 'Bold',
        underline = 'None',
        italic = false,
        strikethrough = false,
      },
      
      inactive_tab = {
        bg_color = palette.dark1,
        fg_color = palette.dimmed2,
      },
      
      inactive_tab_hover = {
        bg_color = palette.dimmed5,
        fg_color = palette.dimmed1,
        italic = false,
      },
      
      new_tab = {
        bg_color = palette.dark1,
        fg_color = palette.dimmed2,
      },
      
      new_tab_hover = {
        bg_color = palette.dimmed5,
        fg_color = palette.dimmed1,
        italic = false,
      },
    },

    -- Scrollbar
    scrollbar_thumb = palette.dimmed4,

    -- Split colors (for pane splits)
    split = palette.dimmed4,

    -- Visual bell
    visual_bell = palette.dimmed5,

    -- Compose cursor (IME)
    compose_cursor = palette.accent2,
  }
end

-- Define color palettes for each variant
local palettes = {
  pro = {
    dark2 = "#19181a",
    dark1 = "#221f22",
    background = "#2d2a2e",
    text = "#fcfcfa",
    accent1 = "#ff6188",
    accent2 = "#fc9867",
    accent3 = "#ffd866",
    accent4 = "#a9dc76",
    accent5 = "#78dce8",
    accent6 = "#ab9df2",
    dimmed1 = "#c1c0c0",
    dimmed2 = "#939293",
    dimmed3 = "#727072",
    dimmed4 = "#5b595c",
    dimmed5 = "#403e41",
  },
  
  octagon = {
    dark2 = "#161821",
    dark1 = "#1e1f2b",
    background = "#282a3a",
    text = "#eaf2f1",
    accent1 = "#ff657a",
    accent2 = "#ff9b5e",
    accent3 = "#ffd76d",
    accent4 = "#bad761",
    accent5 = "#9cd1bb",
    accent6 = "#c39ac9",
    dimmed1 = "#b2b9bd",
    dimmed2 = "#888d94",
    dimmed3 = "#696d77",
    dimmed4 = "#535763",
    dimmed5 = "#3a3d4b",
  },
  
  machine = {
    dark2 = "#161b1e",
    dark1 = "#1d2528",
    background = "#273136",
    text = "#f2fffc",
    accent1 = "#ff6d7e",
    accent2 = "#ffb270",
    accent3 = "#ffed72",
    accent4 = "#a2e57b",
    accent5 = "#7cd5f1",
    accent6 = "#baa0f8",
    dimmed1 = "#b8c4c3",
    dimmed2 = "#8b9798",
    dimmed3 = "#6b7678",
    dimmed4 = "#545f62",
    dimmed5 = "#3a4449",
  },
  
  ristretto = {
    dark2 = "#191515",
    dark1 = "#211c1c",
    background = "#2c2525",
    text = "#fff1f3",
    accent1 = "#fd6883",
    accent2 = "#f38d70",
    accent3 = "#f9cc6c",
    accent4 = "#adda78",
    accent5 = "#85dacc",
    accent6 = "#a8a9eb",
    dimmed1 = "#c3b7b8",
    dimmed2 = "#948a8b",
    dimmed3 = "#72696a",
    dimmed4 = "#5b5353",
    dimmed5 = "#403838",
  },
  
  spectrum = {
    dark2 = "#131313",
    dark1 = "#191919",
    background = "#222222",
    text = "#f7f1ff",
    accent1 = "#fc618d",
    accent2 = "#fd9353",
    accent3 = "#fce566",
    accent4 = "#7bd88f",
    accent5 = "#5ad4e6",
    accent6 = "#948ae3",
    dimmed1 = "#bab6c0",
    dimmed2 = "#8b888f",
    dimmed3 = "#69676c",
    dimmed4 = "#525053",
    dimmed5 = "#363537",
  },
  
  classic = {
    dark2 = "#161613",
    dark1 = "#1d1e19",
    background = "#272822",
    text = "#fdfff1",
    accent1 = "#f92672",
    accent2 = "#fd971f",
    accent3 = "#e6db74",
    accent4 = "#a6e22e",
    accent5 = "#66d9ef",
    accent6 = "#ae81ff",
    dimmed1 = "#c0c1b5",
    dimmed2 = "#919288",
    dimmed3 = "#6e7066",
    dimmed4 = "#57584f",
    dimmed5 = "#3b3c35",
  },

  light = {
    dark2 = "#d3cdcc",
    dark1 = "#ede7e5",
    background = "#faf4f2",
    text = "#29242a",
    accent1 = "#e14775",
    accent2 = "#e16032",
    accent3 = "#cc7a0a",
    accent4 = "#269d69",
    accent5 = "#1c8ca8",
    accent6 = "#7058be",
    dimmed1 = "#706b6e",
    dimmed2 = "#918c8e",
    dimmed3 = "#a59fa0",
    dimmed4 = "#bfb9ba",
    dimmed5 = "#d3cdcc",
  },
}

-- Register all color schemes
function module.register_color_schemes(config)
  if not config.color_schemes then
    config.color_schemes = {}
  end
  
  for name, palette in pairs(palettes) do
    local scheme_name = "Monokai Pro (" .. name:gsub("^%l", string.upper) .. ")"
    config.color_schemes[scheme_name] = create_theme(scheme_name, palette)
  end
end

-- Apply the color scheme
function module.apply_to_config(config, variant)
  -- Register all color schemes first
  module.register_color_schemes(config)
  
  -- Set the default variant (if not specified, use "pro")
  variant = variant or "pro" 
  local scheme_name = "Monokai Pro (" .. variant:gsub("^%l", string.upper) .. ")"

  -- Apply the color scheme
  config.color_scheme = scheme_name
  
  -- Optional: Add inactive pane dimming for better visibility when using splits
  config.inactive_pane_hsb = {
    saturation = 0.8,
    brightness = 0.7,
  }
end

-- Export available variants for easy reference
module.variants = {
  "pro",      -- Default Monokai Pro
  "octagon",  -- Filter Octagon
  "machine",  -- Filter Machine
  "ristretto", -- Filter Ristretto
  "spectrum", -- Filter Spectrum
  "classic",  -- Classic Monokai
  "light",    -- Light theme
}

return module
