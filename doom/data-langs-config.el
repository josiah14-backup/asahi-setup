;;; data-langs-config.el --- Config/data-format languages with no Doom module -*- lexical-binding: t; -*-

;;; Commentary:
;; Languages/formats with no `doom!' :lang module at all -- registered here
;; via the `macrame' package's shared helper instead. Also covers Prolog:
;; Emacs core only auto-binds the ".prolog" extension by default, not the
;; conventional .pl/.pro/.plt (.pl deliberately accepted as a Perl
;; collision -- no Perl support is configured on this machine to collide
;; with).
;;
;; Gaps deliberately left unregistered, because no mode/parser exists for
;; them in any package ecosystem checked (MELPA, nvim-treesitter,
;; vim-polyglot): HOCON (falls back to Emacs core's generic, format-unaware
;; `conf-mode' for its .conf files -- not wrong, just not HOCON-aware),
;; Avro's .avdl IDL (distinct from the JSON-based .avsc handled below), CDDL,
;; Ion. If any of these gain real Emacs support later, they belong in the
;; config list below, not as a new mechanism.

;;; Code:

(dolist (mode->patterns '((protobuf-mode   "\\.proto\\'")
                          (cue-mode        "\\.cue\\'")
                          (conf-toml-mode  "\\.toml\\'")  ; ships in Emacs core
                          (json-mode       "\\.avsc\\'")  ; Avro schema IS JSON
                          (prolog-mode     "\\.pl\\'" "\\.pro\\'" "\\.plt\\'")))
  (macrame-register-mode-patterns 'auto-mode-alist
                                   (cdr mode->patterns)
                                   (car mode->patterns)))

;; forth-mode, gleam-ts-mode, nushell-ts-mode (see packages.el) register
;; their own auto-mode-alist entries on load; sql-mode's .sql binding ships
;; in Emacs core -- none of the four need an entry here.

(provide 'data-langs-config)
;;; data-langs-config.el ends here
