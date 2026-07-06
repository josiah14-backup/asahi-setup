-- Full LSP/IDE tier: C (not C++), Rust, Shell (bash/sh/zsh/ksh), Fish,
-- Nushell, Nix, Python, Lua (already core), TOML, JSON, Zig. Guile Scheme
-- lives in guile.lua (Conjure, not LSP -- no reliable Guile LSP exists).
return {
  -- Official, ready-to-use LazyVim extras -- Mason-managed, zero custom
  -- code needed. Verified each against the installed
  -- lazyvim/plugins/extras/lang/*.lua source directly.
  { import = "lazyvim.plugins.extras.lang.rust" },
  { import = "lazyvim.plugins.extras.lang.nix" },
  { import = "lazyvim.plugins.extras.lang.python" },
  { import = "lazyvim.plugins.extras.lang.toml" },
  { import = "lazyvim.plugins.extras.lang.json" },
  -- Nushell: this extra already does exactly what the Emacs reference
  -- project (docker-emacs's systems-ide) hand-wired for Nushell --
  -- nvim-lspconfig's bundled nushell.lua runs `nu --lsp` (Nushell's own
  -- built-in LSP) plus the "nu" treesitter parser -- confirmed directly
  -- against both source files, no custom code needed at all.
  { import = "lazyvim.plugins.extras.lang.nushell" },

  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "scheme", "zig" } } },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Shell family. nvim-lspconfig's bundled default filetypes for
        -- bashls is {"bash","sh"} (2 entries) -- unlike the clangd case
        -- below, growing that list to 4 entries via a plain override is
        -- safe: vim.tbl_deep_extend("force", ...) only breaks when the
        -- override is SHORTER than the upstream default (indices past
        -- the override's length would otherwise survive from upstream
        -- untouched); here the override is longer, so no FileType-
        -- autocmd workaround is needed, unlike clangd's c-vs-cpp split.
        bashls = { filetypes = { "sh", "bash", "zsh", "ksh" } },

        -- Fish: nvim-lspconfig's bundled fish_lsp.lua already targets
        -- exactly ft=fish, cmd={"fish-lsp","start"} -- no override needed.
        fish_lsp = {},

        -- C only, deliberately NOT C++.
        clangd = {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--fallback-style=llvm",
          },
          root_markers = {
            "compile_commands.json",
            "compile_flags.txt",
            "configure.ac",
            "Makefile",
            "meson.build",
            "meson_options.txt",
            "build.ninja",
            ".git",
          },
          capabilities = { offsetEncoding = { "utf-16" } },
          keys = {
            { "<leader>ch", "<cmd>LspClangdSwitchSourceHeader<cr>", desc = "Switch Source/Header (C)" },
          },
        },

        -- zls: nvim-lspconfig's bundled lsp/zls.lua already scopes itself
        -- correctly to filetypes {"zig","zir"} with plain cmd={"zls"} --
        -- no FileType-autocmd workaround needed here, unlike clangd above.
        -- Mason does have a linux_arm64 build for it (confirmed against
        -- mason-registry's packages/zls/package.yaml) -- added to the
        -- Main.hs headless MasonInstall list alongside shellcheck below,
        -- for the same reason shellcheck needs to be there: a headless
        -- `+qa` provisioning run never fires the FileType/BufReadPre event
        -- this table's own auto-install is gated behind.
        zls = {},
      },
      setup = {
        clangd = function(_, server_opts)
          -- Upstream nvim-lspconfig's bundled clangd default has 7
          -- filetypes (c, cpp, objc, ...). A plain `filetypes = {"c"}`
          -- override would NOT drop "cpp" -- confirmed directly:
          -- vim.tbl_deep_extend("force", {7 entries}, {"c"}) keeps
          -- indices 2-7 from the base table since the override is
          -- shorter, so vim.lsp.enable("clangd")'s generic FileType
          -- auto-attach would still fire on .cpp buffers. So: register
          -- the config but return `true` (skips LazyVim's normal
          -- vim.lsp.enable path for this server) and start the client
          -- ourselves from a FileType autocmd scoped to exactly "c".
          vim.lsp.config("clangd", server_opts)
          vim.api.nvim_create_autocmd("FileType", {
            pattern = "c",
            callback = function(args)
              local root_dir = vim.fs.root(args.buf, server_opts.root_markers or { ".git" })
              vim.lsp.start(
                vim.tbl_extend("force", vim.lsp.config.clangd, { root_dir = root_dir }),
                { bufnr = args.buf }
              )
            end,
          })
          return true
        end,
      },
    },
  },

  -- shellcheck: a lint tool, not an LSP server, so it's invisible to the
  -- opts.servers-driven mason-lspconfig auto-install above -- needs its
  -- own nvim-lint wiring plus its own mason.nvim ensure_installed entry.
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        sh = { "shellcheck" },
        bash = { "shellcheck" },
        zsh = { "shellcheck" },
        ksh = { "shellcheck" },
      },
    },
  },
  { "mason-org/mason.nvim", opts = { ensure_installed = { "shellcheck" } } },
}
