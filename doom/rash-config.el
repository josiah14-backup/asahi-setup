;;; rash-config.el --- Best-effort support for Rash (#lang rash) -*- lexical-binding: t; -*-

;;; Commentary:
;; Rash (https://docs.racket-lang.org/rash/) is a `#lang rash' shell-scripting
;; DSL embedded in Racket. No dedicated Emacs major mode or LSP exists for it
;; anywhere -- confirmed via web search; the project has seen no activity
;; since ~Jan 2024. This is a permanent ceiling, not a gap to close later:
;; falling back to plain `racket-mode' gives generic Racket S-expression
;; highlighting and paren-matching, with no awareness of Rash's own
;; shell-escape syntax. Revisit only if Rash itself ships real tooling.

;;; Code:

(+asahi/register-mode-patterns 'auto-mode-alist '("\\.rash\\'") 'racket-mode)
(+asahi/register-mode-patterns 'interpreter-mode-alist '("rash") 'racket-mode)

(provide 'rash-config)
;;; rash-config.el ends here
