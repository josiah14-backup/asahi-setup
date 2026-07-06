;;; init.el -*- lexical-binding: t; -*-

;; Non-:lang categories mirror the baseline already established in
;; ~/Development/personal/automation-engineering/docker-emacs's systems-ide
;; config (this machine's other, more current Doom reference point) rather
;; than being invented fresh here.

(doom! :completion
       (company +auto)
       (vertico +icons)

       :ui
       doom
       doom-dashboard
       hl-todo
       indent-guides
       modeline
       (popup +defaults)
       treemacs
       unicode
       workspaces

       :editor
       (evil +everywhere)
       file-templates
       fold
       snippets

       :emacs
       dired
       electric
       ibuffer
       undo
       vc

       :term
       eshell
       vterm

       :checkers
       syntax

       :tools
       (debugger +lsp)
       direnv
       docker
       editorconfig
       (eval +overlay)
       (lookup +dictionary)
       lsp
       magit
       make
       tree-sitter          ; hard dependency, not optional: `doom doctor`
                             ; confirmed (cc +tree-sitter) asserts this
                             ; module is enabled and fails otherwise --
                             ; see modules/lang/cc/doctor.el's own
                             ; assert!. Emacs 30.2 is already built with
                             ; --with-tree-sitter (installEmacsFromSource)

       ;; :lang below mirrors this repo's nvim/lua/plugins/lang-{full,basic}.lua
       ;; and lang-data.lua breadth, tier-for-tier (+lsp only where nvim also
       ;; has real LSP wiring), plus Haskell/Racket at FULL LSP -- new
       ;; capability that doesn't exist on the nvim side of this repo at all.
       ;; See app/Main.hs's plan-file writeup for the full verification trail.
       :lang
       (cc +lsp +tree-sitter)         ; C only -- see c-config.el
       clojure (+tree-sitter)         ; basic tier; also gives EDN for free
       common-lisp                    ; basic tier+ (Sly REPL, needs sbcl)
       data                           ; JSON/YAML/TOML/etc. shared infra module
       elixir (+tree-sitter)          ; basic tier
       elm                            ; basic tier, mirrors nvim (no +lsp)
       erlang (+tree-sitter)          ; basic tier
       go                             ; basic tier, mirrors nvim (no +lsp --
                                       ; nvim has no gopls wiring either)
       (haskell +lsp +tree-sitter)    ; FULL LSP -- new capability beyond nvim
       idris                          ; basic tier, mirrors nvim (no +lsp)
       java (+tree-sitter)            ; basic tier
       javascript (+tree-sitter)      ; basic tier (covers JS+TS, mirrors nvim)
       (json +lsp +tree-sitter)       ; mirrors nvim's LazyVim json extra
       julia (+tree-sitter)           ; basic tier
       (nix +lsp +tree-sitter)        ; mirrors nvim's LazyVim nix extra
       ocaml                          ; basic tier (tuareg, no +lsp)
       org
       (python +lsp +pyright +tree-sitter +poetry)  ; +poetry: this machine
                                       ; already standardizes on Poetry for
                                       ; Python dependency management (see
                                       ; Main.hs's installPoetry/pyenv setup)
       (racket +lsp +xp +hash-lang)   ; FULL LSP -- new capability beyond nvim
       ruby                           ; basic tier
       (rust +lsp +tree-sitter)       ; mirrors nvim's rust-analyzer
       scala (+tree-sitter)           ; basic tier
       (scheme +guile +chez)          ; REPL tier via Geiser -- mirrors nvim's
                                       ; Conjure-based guile.lua, covers Chez
                                       ; too (real Geiser REPL beats nvim's
                                       ; "bundled syntax, no REPL" baseline)
       (sh +lsp +fish)                ; bash LSP mirrors nvim's bashls; +fish
                                       ; is SYNTAX ONLY, see lsp-clients.el
                                       ; for the hand-rolled fish-lsp gap fix
       sml                            ; basic tier -- real sml-mode beats
                                       ; nvim's bundled-syntax.vim baseline
       yaml (+tree-sitter)            ; basic tier, per explicit "syntax only"
       (zig +lsp +tree-sitter)        ; FULL LSP, explicit request

       :config
       (default +bindings +smartparens))

;; Deliberately LEFT DISABLED even though Doom has real modules for them, to
;; stay tier-symmetric with nvim's own deliberate "leave as plain text"
;; choices (Lean4/Pharo/Hy/Coconut/Factor -- see lang-basic.lua's own
;; comments on this machine): `factor', `hy', `lean'. One-line flips in the
;; block above if ever wanted -- not silently enabled, since nvim's exclusion
;; of these was an explicit historical decision, not a gap.
;;
;; `gleam', `forth', `nushell', `toml', `sql', `protobuf', `hocon', `cue',
;; `cddl', `edn', `ion', `avro' have NO official Doom :lang module at all
;; (confirmed absent from doomemacs/modules' modules/lang/ directory) --
;; handled via hand-rolled packages.el + auto-mode-alist wiring instead, see
;; data-langs-config.el and packages.el.
