;;; lsp-clients.el --- Hand-rolled lsp-mode clients for languages with no Doom module -*- lexical-binding: t; -*-

;;; Commentary:
;; TOML, Nushell, and Fish each have a real language server but no official
;; Doom :lang module wiring one up for them on this machine's chosen backend
;; (lsp-mode, not eglot -- see init.el's :tools lsp entry):
;;   - TOML: Doom has no :lang toml module at all (confirmed absent from
;;     doomemacs/modules). nvim already gets this via LazyVim's toml extra +
;;     taplo; this closes the same gap here.
;;   - Nushell: no official module either; `nu --lsp' is the exact mechanism
;;     nvim-lspconfig's bundled nushell.lua already uses.
;;   - Fish: Doom's `(sh +fish)' flag (see init.el) only adds Fish syntax
;;     support, not LSP -- nvim gets fish-lsp via LazyVim's fish extra, so
;;     this closes a real asymmetry rather than adding a new capability.
;;
;; The registration mechanism itself (`macrame-register-lsp-client') lives
;; in the `macrame' package (see packages.el) -- extracted there since the
;; same "tell lsp-mode a server exists for a major mode, then start it via
;; a hook" pattern also recurs in docker-emacs's Doom configs.

;;; Code:

;; UNVERIFIED: confirm `nushell-ts-mode'/`fish-mode' are the real mode
;; symbols exposed by whichever package version actually loads (see
;; packages.el) -- the registration mechanism is standard lsp-mode usage;
;; only these two symbols need a final check once installed.
(after! lsp-mode
  (macrame-register-lsp-client 'taplo       '(conf-toml-mode)  '("taplo" "lsp" "stdio") 'conf-toml-mode-hook)
  (macrame-register-lsp-client 'nushell-lsp '(nushell-ts-mode) '("nu" "--lsp")          'nushell-ts-mode-hook)
  (macrame-register-lsp-client 'fish-lsp    '(fish-mode)       '("fish-lsp" "start")    'fish-mode-hook))

(provide 'lsp-clients)
;;; lsp-clients.el ends here
