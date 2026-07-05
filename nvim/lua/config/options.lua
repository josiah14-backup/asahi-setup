-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Neovim's builtin vim.filetype has no ".nu" -> "nu" mapping at all
-- (unlike sh/bash/zsh, which it does know), and neither
-- lazyvim.plugins.extras.lang.nushell nor the "nu" treesitter parser
-- registers one either -- confirmed directly: opening a .nu file
-- resulted in an empty filetype and no LSP attaching at all despite the
-- nushell extra being correctly imported.
--
-- `vim.filetype.add({extension = {nu = "nu"}})` alone does NOT fix
-- this, even placed here in options.lua (loaded before lazy.nvim
-- startup, confirmed via a direct marker-file test that this file does
-- run that early) -- confirmed the registration itself is correct
-- (`vim.filetype.match({filename=...})` reflects it immediately), but
-- the actual buffer's `filetype` option still comes back empty, and
-- `:filetype detect` run manually afterward DOES then correctly set it
-- -- so Neovim's own initial per-buffer filetype detection is racing
-- ahead of this registration somehow, for reasons not fully root-caused.
-- An explicit BufRead/BufNewFile autocmd sidesteps the race entirely by
-- just setting the option directly, the traditional ftdetect idiom.
vim.filetype.add({ extension = { nu = "nu" } })
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.nu",
  callback = function(args)
    vim.bo[args.buf].filetype = "nu"
  end,
})

-- mason.nvim's own plugin spec is `cmd = "Mason"` -- it only prepends
-- ~/.local/share/nvim/mason/bin to $PATH once that command actually
-- runs, which never happens in normal day-to-day editing. LSP servers
-- work regardless (mason-lspconfig resolves their full path directly,
-- bypassing $PATH lookup entirely), but nvim-lint's shellcheck entry
-- (lang-full.lua) just calls the bare "shellcheck" name and expects it
-- resolvable via $PATH -- confirmed directly: `vim.fn.executable
-- ("shellcheck")` returned 0 in an ordinary session that never invoked
-- :Mason, even though the binary was already installed and worked fine
-- when called by its full path. Prepending this here, unconditionally
-- and early, sidesteps the whole "did something else already load
-- mason.nvim" question.
vim.env.PATH = vim.fn.stdpath("data") .. "/mason/bin:" .. vim.env.PATH
