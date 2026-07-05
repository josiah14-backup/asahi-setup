-- Solarized Dark, matching this whole machine's theming (Hyprland
-- borders, waybar, fuzzel, Konsole/foot, Plasma, GTK, qt6ct all use the
-- same canonical palette -- see asahi-setup's theming notes). Verified
-- directly against maxmx03/solarized.nvim's own source
-- (lua/solarized/palette/init.lua) that its default `palette =
-- "solarized"` table uses the exact same canonical hex values already
-- used everywhere else (base03 #002B36, base02 #073642, base01 #586E75,
-- base0 #839496, blue #268BD2, cyan #2AA198, etc.) -- not the plugin's
-- alternate "selenized" palette, which is a different, related-but-
-- distinct color set.
return {
  {
    "maxmx03/solarized.nvim",
    lazy = false,
    priority = 1000,
    ---@type solarized.config
    opts = {
      palette = "solarized",
    },
    config = function(_, opts)
      vim.o.termguicolors = true
      vim.o.background = "dark"
      require("solarized").setup(opts)
      vim.cmd.colorscheme("solarized")
    end,
  },

  -- Configure LazyVim to load solarized (lualine and other LazyVim
  -- internals check this for theme-name-aware integrations).
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "solarized",
    },
  },
}
