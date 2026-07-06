-- Config/data-format languages: syntax highlighting only, no LSP, per
-- explicit request. Distinct file from lang-basic.lua on purpose -- that
-- file's own framing is "real programming languages I'll have per-project
-- IDEs for elsewhere"; these are config/data formats instead.
--
-- One plugin-spec entry, not two: `opts` and `init` are both keys on the
-- same "nvim-treesitter/nvim-treesitter" spec, not separate array entries
-- for the same plugin -- lazy.nvim merges same-name specs across files
-- regardless (that's how this file's own ensure_installed fragment
-- combines with lang-basic.lua's and lang-full.lua's), but splitting one
-- file's OWN contribution into two entries buys nothing and reads as if
-- they were unrelated concerns.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        -- Confirmed real parsers exist (checked directly against the
        -- installed nvim-treesitter/lua/nvim-treesitter/parsers.lua).
        "sql",
        "proto", -- Protobuf; nvim core already maps .proto -> "proto"
        "yaml",
        "hocon",
        -- CUE: nvim core already maps .cue -> filetype "cue", zero extra
        -- config. Note vim-polyglot's only "cue"-named file (cuesheet.vim)
        -- is CD/DVD cue sheets, an unrelated format -- not a real conflict,
        -- so "cue" does NOT need a lang-basic.lua polyglot_disabled entry
        -- the way sql/proto/yaml (real polyglot packs) do.
        "cue",
        -- "clojure" is already in lang-basic.lua's ensure_installed and
        -- also covers EDN: nvim core already maps .edn -> filetype
        -- "clojure" by default (confirmed live via vim.filetype.match) --
        -- nothing to add here for EDN specifically.
      },
    },
    -- nvim core has no default filetype detection for these extensions
    -- (confirmed live via vim.filetype.match returning nil) even though a
    -- real treesitter parser exists for hocon -- register them explicitly.
    -- HOCON conventionally uses bare .conf (application.conf/reference.conf,
    -- Lightbend's own convention), which collides with every other .conf
    -- file in existence -- matched by filename, not blanket extension, so
    -- unrelated .conf files aren't mis-highlighted as HOCON.
    init = function()
      vim.filetype.add({
        extension = {
          hocon = "hocon",
          avsc = "json", -- Avro schema files ARE JSON; free win, no parser needed
        },
        filename = {
          ["application.conf"] = "hocon",
          ["reference.conf"] = "hocon",
        },
      })
    end,
  },

  -- Ion (Amazon Ion) and CDDL: confirmed NO treesitter parser, NO
  -- vim-polyglot pack exists for either (vim-polyglot's only "ion" pack,
  -- vmchale/ion-vim, is for the unrelated Redox OS "Ion shell" scripting
  -- language -- a false-friend name collision, not Amazon Ion). Avro's
  -- .avdl (its own IDL, distinct from the JSON-based .avsc above) has no
  -- solution anywhere either. All three left as plain text, same
  -- precedent as Lean4/Pharo/Hy/Coconut/Factor in lang-basic.lua.
}
