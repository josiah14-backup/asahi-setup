;;; c-config.el --- Scope :lang cc's LSP to C only, not C++/Obj-C -*- lexical-binding: t; -*-

;;; Commentary:
;; Mirrors this machine's nvim clangd setup (nvim/lua/plugins/lang-full.lua),
;; which deliberately gives C full LSP support while leaving C++ at
;; treesitter-only. Doom's `(cc +lsp)' module (see modules/lang/cc/config.el)
;; wires `#'lsp!' into five hooks: c-mode, c-ts-mode, c++-mode, c++-ts-mode,
;; and objc-mode's respective *-local-vars-hook. There's no module flag to
;; narrow that to C alone, so this removes it from the C++/Obj-C hooks after
;; the module has already installed them -- config.el loads after every
;; module (see DOOM-EMACS-GUIDE.md's boot sequence), so this is guaranteed
;; to run after `+lsp' populated the hooks, not before.

;;; Code:

(dolist (hook '(c++-mode-local-vars-hook
                c++-ts-mode-local-vars-hook
                objc-mode-local-vars-hook))
  (remove-hook hook #'lsp!))

(provide 'c-config)
;;; c-config.el ends here
