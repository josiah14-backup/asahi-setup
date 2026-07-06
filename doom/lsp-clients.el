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
;; All three need identical plumbing (tell lsp-mode a server exists for a
;; major mode, then start it when that mode's buffer opens), so that's
;; extracted into one function below instead of three near-copies of
;; `lsp-register-client'/`add-hook'. Wrapped in `after! lsp-mode' because
;; `make-lsp-client'/`lsp-stdio-connection' are real lsp-mode functions, not
;; autoloaded stubs -- calling them before lsp-mode has actually loaded
;; would signal void-function, not just do nothing.

;;; Code:

(defun +asahi/register-lsp-client (server-id major-modes command hook)
  "Register COMMAND as the lsp-mode client SERVER-ID for MAJOR-MODES,
started automatically via HOOK.
MAJOR-MODES is a list of major-mode symbols sharing one server; COMMAND is
the server's argv as a list of strings; HOOK is the mode hook to attach to."
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-stdio-connection command)
                     :major-modes major-modes
                     :server-id server-id))
  (add-hook hook #'lsp!))

;; UNVERIFIED: confirm `nushell-ts-mode'/`fish-mode' are the real mode
;; symbols exposed by whichever package version actually loads (see
;; packages.el) -- the registration mechanism above is standard lsp-mode
;; usage; only these two symbols need a final check once installed.
(after! lsp-mode
  (+asahi/register-lsp-client 'taplo       '(conf-toml-mode)  '("taplo" "lsp" "stdio") 'conf-toml-mode-hook)
  (+asahi/register-lsp-client 'nushell-lsp '(nushell-ts-mode) '("nu" "--lsp")          'nushell-ts-mode-hook)
  (+asahi/register-lsp-client 'fish-lsp    '(fish-mode)       '("fish-lsp" "start")    'fish-mode-hook))

(provide 'lsp-clients)
;;; lsp-clients.el ends here
