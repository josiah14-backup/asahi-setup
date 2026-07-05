-- Guile Scheme: REPL-based interactive development via Conjure, matching
-- Geiser's role in the Emacs reference project (docker-emacs's
-- systems-ide) -- no reliable Guile LSP exists. Conjure never spawns
-- Guile itself (verified against Olical/conjure's
-- lua/conjure/client/guile/socket.lua): start a REPL by hand first with
-- `guile3.0 --listen=/path/to/socket` (Unix socket) or plain
-- `guile3.0 --listen` (TCP, localhost:37146) -- NOTE: the binary is
-- `guile3.0`, not `guile` (Fedora's guile30 package doesn't provide a
-- plain `guile` symlink; see app/Main.hs). Then use <localleader>cc in a
-- .scm buffer to connect.
return {
  {
    "Olical/conjure",
    ft = { "scheme" },
    init = function()
      vim.g["conjure#filetype#scheme"] = "conjure.client.guile.socket"
      vim.g["conjure#client#guile#socket#host_port"] = "localhost"
    end,
  },
}
