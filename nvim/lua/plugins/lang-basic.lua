-- Basic syntax-highlighting-only tier: languages Josiah expects to see
-- on this machine but will have dedicated per-project IDEs for
-- elsewhere, so just "good enough to read" support here, not full LSP.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        -- Confirmed real parsers exist (checked directly against the
        -- installed nvim-treesitter/lua/nvim-treesitter/parsers.lua).
        "commonlisp",
        "elixir",
        "gleam",
        "erlang",
        "haskell",
        "ocaml",
        "ocaml_interface",
        "ruby",
        "idris",
        "go",
        "racket",
        "julia",
        "forth",
        "prolog",
        "cpp",
        -- Added later in the same conversation, also confirmed:
        "clojure",
        "scala",
        "java",
        "javascript",
        "typescript",
        "elm",
      },
    },
  },

  -- Fallback traditional (non-treesitter) syntax highlighting, for the
  -- one requested language with no treesitter parser that vim-polyglot
  -- DOES cover. (Standard ML and Chez Scheme need nothing at all --
  -- Neovim's own bundled runtime already ships syntax/sml.vim and
  -- syntax/scheme.vim, confirmed directly at /usr/share/nvim/runtime/.
  -- Lean 4, Mercury, Pharo, Hy, Coconut, Factor: no highlighting
  -- solution anywhere -- confirmed absent from both nvim-treesitter and
  -- vim-polyglot -- left as plain text per explicit request.)
  --
  -- vim-polyglot enables ~150 packs by default (g:polyglot_disabled is
  -- an EXCLUDE list, must be set in `init`, before the plugin loads) --
  -- disabling every pack that overlaps a treesitter-covered language
  -- here avoids double-highlighting/ftdetect conflicts. idris2 is
  -- deliberately left enabled alongside the treesitter "idris" parser:
  -- that grammar may only fully cover Idris 1 syntax, so leaving both
  -- active is a safe hedge, not an oversight.
  {
    "sheerun/vim-polyglot",
    init = function()
      vim.g.polyglot_disabled = {
        "c",
        "cpp",
        "elixir",
        "erlang",
        "gleam",
        "go",
        "haskell",
        "javascript",
        "json",
        "json5",
        "jsonc",
        "julia",
        "lua",
        "markdown",
        "nix",
        "ocaml",
        "python",
        "racket",
        "ruby",
        "rust",
        "sh",
        "toml",
        "typescript",
        "clojure",
        "scala",
        "java",
        "elm",
      }
    end,
  },
}
