;;; packages.el -*- lexical-binding: t; -*-

;; Shared, project-agnostic helpers (mode-alist registration, hand-rolled
;; lsp-mode client setup) extracted into their own standalone package once
;; the same patterns started recurring across this repo and docker-emacs's
;; Doom configs -- see https://github.com/josiah14-automation-engineering/macrame.
(package! macrame
  :recipe (:host github :repo "josiah14-automation-engineering/macrame"))

;; Hand-rolled additions for languages with no official Doom :lang module
;; (confirmed absent from doomemacs/modules' modules/lang/ directory) --
;; same spirit as this machine's nvim/lua/plugins/lang-basic.lua reaching
;; past LazyVim's official extras.
(package! protobuf-mode)      ; MELPA, real, confirmed
(package! cue-mode)           ; MELPA, real, confirmed (russell/cue-mode)
(package! forth-mode)         ; MELPA, real, confirmed
(package! gleam-ts-mode)      ; MELPA, real, confirmed (tree-sitter, needs Emacs 29+)
(package! nushell-mode)       ; MELPA, real, confirmed
(package! nushell-ts-mode)    ; MELPA, real, confirmed (tree-sitter variant, preferred)

;; No MELPA package exists for: hocon-mode, cddl-mode, ion-mode, avro-mode --
;; see data-langs-config.el for the honest gap notes. edn-mode ships INSIDE
;; clojure-mode itself (already installed by the `clojure' :lang module) --
;; do not add a separate `edn' package, that names an unrelated elisp
;; data-reader library, not a major mode.

;; Works around a real bug in Doom's own :lang go module (modules/lang/
;; go/doctor.el unconditionally `(require 'company-go)` whenever `company`
;; is the active completion framework and +lsp is off, but go/packages.el
;; never actually declares company-go as a dependency) -- confirmed live:
;; without this, `doom doctor` hits a file-missing error on a fresh
;; install and exits nonzero, which is fatal to this repo's provisioning
;; script (see Main.hs's installDoomEmacs comment on `shell` vs `shells`).
;; company-go itself is effectively abandoned (emacsattic/company-go,
;; last touched 2017, tied to the also-abandoned `gocode` daemon Go
;; tooling replaced with gopls years ago) -- installing it doesn't restore
;; real completion, it just satisfies the `require` so doctor.el's own
;; intended graceful path (warn if `gocode` isn't found) runs instead of
;; crashing outright.
(package! company-go)
