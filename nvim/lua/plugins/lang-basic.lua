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
        -- NOT haskell -- see the vim-polyglot block below for why.
        "commonlisp",
        "elixir",
        "gleam",
        "erlang",
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

  -- Fallback traditional (non-treesitter) syntax highlighting, for
  -- requested languages with no SAFE treesitter parser that
  -- vim-polyglot DOES cover. (Standard ML and Chez Scheme need nothing
  -- at all -- Neovim's own bundled runtime already ships
  -- syntax/sml.vim and syntax/scheme.vim, confirmed directly at
  -- /usr/share/nvim/runtime/. Lean 4, Pharo, Hy, Coconut, Factor: no
  -- highlighting solution anywhere -- confirmed absent from both
  -- nvim-treesitter and vim-polyglot -- left as plain text per explicit
  -- request. Mercury is covered separately below, not via vim-polyglot
  -- -- vim-polyglot itself has no Mercury pack.)
  --
  -- vim-polyglot enables ~150 packs by default (g:polyglot_disabled is
  -- an EXCLUDE list, must be set in `init`, before the plugin loads) --
  -- disabling every pack that overlaps a treesitter-covered language
  -- here avoids double-highlighting/ftdetect conflicts. idris2 is
  -- deliberately left enabled alongside the treesitter "idris" parser:
  -- that grammar may only fully cover Idris 1 syntax, so leaving both
  -- active is a safe hedge, not an oversight.
  --
  -- MAINTENANCE INVARIANT: this list must cover every language given a
  -- real treesitter parser ANYWHERE in this config (this file,
  -- lang-full.lua's LazyVim extras, lang-data.lua), not just the parsers
  -- installed by this file alone -- rust/nix/python/sh/toml below are
  -- proof this is already a cross-file list, not a local one. When adding
  -- a new treesitter-covered language in any lang-*.lua file, check
  -- whether vim-polyglot has a same-named pack (grep its own installed
  -- syntax/ directory directly, don't assume by name -- "cue" and "ion"
  -- both have deceptive false-friend polyglot files: cuesheet.vim is CD/
  -- DVD cue sheets, not the CUE config language, and vim-polyglot's own
  -- "ion" pack is the unrelated Redox OS Ion shell, not Amazon Ion --
  -- neither needs an entry here because of this) and add it here if so.
  -- sql/proto/yaml (added alongside lang-data.lua) were found exactly
  -- this way -- confirmed via vim-polyglot's syntax/{sql,proto,yaml}.vim
  -- all being real, installed files.
  --
  -- haskell is deliberately NOT in this disabled list, unlike every
  -- other treesitter-covered language here -- the nvim-treesitter
  -- "haskell" parser has a real memory-corruption bug, confirmed
  -- directly: opening this repo's own app/Main.hs (a large, real
  -- Haskell file) reliably crashed even plain headless `nvim` with
  -- "malloc(): mismatching next->prev_size (unsorted)" (a raw glibc
  -- heap-corruption abort), reproduced consistently, and confirmed
  -- fixed by removing the compiled haskell.so parser -- with it gone,
  -- the same file opens fine. So haskell was removed from
  -- ensure_installed above entirely, and vim-polyglot's own
  -- (non-treesitter, so unaffected by this bug) haskell.vim pack
  -- covers the highlighting instead.
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
        "javascript",
        "json",
        "json5",
        "jsonc",
        "julia",
        "lua",
        "markdown",
        "nix",
        "ocaml",
        "proto",
        "python",
        "racket",
        "ruby",
        "rust",
        "sh",
        "sql",
        "toml",
        "typescript",
        "yaml",
        "clojure",
        "scala",
        "java",
        "elm",
      }
    end,
  },

  -- Mercury: no nvim-treesitter parser and no vim-polyglot pack exist
  -- for it at all, but the language's own upstream repo (and several
  -- community forks of the same thing) ship a standard ftdetect/
  -- ftplugin/syntax vim plugin. Deliberately NOT ft-scoped (no `ft =`
  -- key): its own ftdetect script is what registers ".m"/".moo" as
  -- Mercury in the first place, so lazy-loading it ON that filetype
  -- would be a chicken-and-egg deadlock -- same class of issue already
  -- hit with Nushell's filetype registration. LazyVim's own default for
  -- custom plugins with no explicit trigger is `lazy = false` (see
  -- config/lazy.lua's `defaults.lazy = false`), so a bare spec entry
  -- here is enough, matching vim-polyglot's own entry above.
  --
  -- NOTE: claims the ".m" extension unconditionally, which collides
  -- with Objective-C and MATLAB (both also ".m") -- accepted knowingly,
  -- since neither was requested for this machine.
  { "yzhs/mercury-vim" },
}
