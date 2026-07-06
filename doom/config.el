;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Matches this machine's Solarized Dark theming everywhere else (Hyprland,
;; waybar, fuzzel, Konsole/foot, Plasma/qt6ct, GTK -- see the asahi-setup
;; repo's theming pass).
(setq doom-theme 'doom-solarized-dark)

;; No doom-font was ever set, so Doom fell back to its own bare default,
;; which read noticeably smaller than the rest of this machine -- same
;; "check/set an explicit font+size" gotcha this repo's own theming notes
;; already flag as recurring. 11pt (this machine's foot/Konsole/qt6ct
;; convention) was confirmed live to still read too small in Doom's own
;; pgtk-rendered GUI frame, so this uses 16pt instead, matching the size
;; the docker-emacs reference project's own real doom-font example uses.
(setq doom-font (font-spec :family "Hack Nerd Font Mono" :size 15))

;; Verbatim port of this repo's emacs/init.el -- the plain-Emacs GC tuning
;; this machine already settled on before Doom existed here. Emacs's default
;; GC threshold (~800KB) triggers collection very frequently on modern
;; hardware; raising both the absolute threshold and the percentage-of-heap-
;; growth trigger means GC runs far less often during normal editing, at the
;; cost of more memory used between collections -- a reasonable trade with
;; plenty of RAM available.
(setq gc-cons-threshold (* 64 1024 1024))
(setq gc-cons-percentage 0.5)

;; Doom's :tools tree-sitter module (modules/tools/tree-sitter/config.el)
;; installs grammars LAZILY, the first time a matching buffer's major mode
;; gets remapped to its `-ts-mode' variant -- confirmed directly by reading
;; that module's own +tree-sitter--maybe-remap-major-mode-a advice. The
;; default `treesit-auto-install-grammar' value ('ask) means the very
;; first time you open a .hs/.rs/.py/etc. file, Doom prompts
;; interactively ("Missing tree-sitter grammars: haskell. Install now?"),
;; or silently falls back to the non-treesit major mode if unanswered --
;; not a bug specific to Haskell, but the exact same lazy gap every
;; +tree-sitter-flagged :lang module in init.el shares (cc, elixir,
;; erlang, haskell, java, javascript, julia, json, nix, python, rust,
;; scala, yaml, zig). 'always matches this whole repo's "provisioning
;; should need zero manual follow-up" convention.
(setq treesit-auto-install-grammar 'always)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; load language configs
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mode-alist-utils loads first: data-langs-config and rash-config both
;; depend on the helper it provides.
(load! "mode-alist-utils")
(load! "data-langs-config")
(load! "rash-config")
(load! "c-config")
(load! "lsp-clients")
