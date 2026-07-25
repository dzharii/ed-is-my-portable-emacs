;;; early-init.el --- Loaded before package system and first frame  -*- lexical-binding: t; -*-
;;
;; This file runs BEFORE package initialization and before the initial frame is
;; created, so it is the right place for:
;;   - redirecting package + native-comp caches OFF OneDrive (keeps the synced
;;     config folder tiny; only source files sync, not hundreds of package files)
;;   - startup GC tuning
;;   - Windows performance tweaks
;;   - clean frame chrome (no toolbar) with no visual flicker

;; --- Keep OneDrive light: put packages / eln-cache in a local (non-synced) dir
(defvar ed-cache-dir
  (file-name-as-directory
   (expand-file-name "emacs-ed"
                     (or (getenv "LOCALAPPDATA") temporary-file-directory)))
  "Local, non-synced directory for ed's packages, native-comp cache, backups.")

(setq package-user-dir (expand-file-name "elpa/" ed-cache-dir))

(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (convert-standard-filename (expand-file-name "eln-cache/" ed-cache-dir))))

;; --- Faster startup: raise GC during init, restore a sane value afterwards
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 32 1024 1024)
                  gc-cons-percentage 0.1)))

;; --- Windows-specific performance
(when (eq system-type 'windows-nt)
  (setq w32-pipe-read-delay 0)              ; snappier subprocess/LSP/eshell I/O
  (setq inhibit-compacting-font-caches t))  ; avoid GC pauses on wide-glyph files

;; --- Clean, modern chrome (set here to avoid a flash of toolbar on startup)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars . nil) default-frame-alist)
(setq tool-bar-mode nil
      scroll-bar-mode nil)

;; package.el is initialized normally after this file; don't do it twice.
(setq package-enable-at-startup t)

;;; early-init.el ends here
