;; Minimal init.el from asahi-setup: just the GC threshold tuning that was
;; actually asked for, nothing else. This deliberately isn't a full personal
;; Emacs config -- add your own on top of this.

;; Emacs's default GC threshold (~800KB) triggers collection very
;; frequently on modern hardware. Raising both the absolute threshold and
;; the percentage-of-heap-growth trigger means GC runs far less often
;; during normal editing, at the cost of using more memory between
;; collections -- a reasonable trade on a machine with plenty of RAM.
(setq gc-cons-threshold (* 64 1024 1024))
(setq gc-cons-percentage 0.5)
