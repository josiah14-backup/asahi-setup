-- Common Lisp: REPL-based interactive development via Conjure, matching
-- Doom's Sly (see doom/init.el's `common-lisp` module) as the "real IDE
-- support" equivalent -- Common Lisp doesn't have a mainstream LSP server,
-- so a live-image REPL protocol (SLIME/Sly/swank) is the actual state of
-- the art here, same reasoning as Guile in guile.lua.
--
-- Unlike Sly (which bundles and auto-loads its own slynk server the moment
-- you run `sly` in Emacs), Conjure's common-lisp client speaks plain swank
-- and does NOT spawn sbcl itself -- confirmed directly against Conjure's
-- own doc (conjure-client-common-lisp-swank.txt): start sbcl by hand in a
-- separate terminal first, `(ql:quickload :swank)` then
-- `(swank:create-server :dont-close t)`, then open a .lisp buffer here and
-- <localleader>cc connects to the default host/port (127.0.0.1:4005).
-- `(ql:quickload :swank)` needs Quicklisp actually installed (see
-- app/Main.hs's installQuicklisp, which also registers it in ~/.sbclrc via
-- `(ql:add-to-init-file)` so a plain `sbcl` session can quickload without
-- an extra manual `(load ...)` step first).
return {
  {
    "Olical/conjure",
    ft = { "lisp" },
  },
}
