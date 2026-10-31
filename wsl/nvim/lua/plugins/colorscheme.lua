-- Catppuccin Mocha for LazyVim (~/.config/nvim/lua/plugins/colorscheme.lua)
return {
  { "catppuccin/nvim", name = "catppuccin", priority = 1000, opts = { flavour = "mocha" } },
  { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin" } },
}
