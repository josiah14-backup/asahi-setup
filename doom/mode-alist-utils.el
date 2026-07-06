;;; mode-alist-utils.el --- Shared helper for mode-dispatch alist registration -*- lexical-binding: t; -*-

;;; Commentary:
;; Extracted because the same shape of work -- "map N regexp/string patterns
;; onto one major mode, in one of Emacs's mode-dispatch alists" -- is needed
;; by both data-langs-config.el (auto-mode-alist, by file extension) and
;; rash-config.el (interpreter-mode-alist, by shebang interpreter name).
;; Parameterizing over the alist itself, rather than writing one
;; auto-mode-alist-specific helper per consumer, is what actually makes this
;; reusable; a helper hardcoded to a single alist variable wouldn't have
;; served the second caller and would invite a near-duplicate later.
;;
;; This is loaded first (see config.el's `load!' order) so every other
;; per-language file here can depend on it.

;;; Code:

(defun +asahi/register-mode-patterns (alist-var patterns mode)
  "Add each entry in PATTERNS to ALIST-VAR, mapped to MODE.
ALIST-VAR is a symbol naming a mode-dispatch alist such as
`auto-mode-alist' or `interpreter-mode-alist'. PATTERNS is a list of
strings/regexps in whatever form ALIST-VAR itself expects."
  (dolist (pattern patterns)
    (add-to-list alist-var (cons pattern mode))))

(provide 'mode-alist-utils)
;;; mode-alist-utils.el ends here
