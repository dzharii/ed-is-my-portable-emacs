;;; init-config.el --- tangled from init-config.org  -*- lexical-binding: t; -*-

(require 'package)
(require 'seq)

(defgroup ed nil
  "Portable ed configuration."
  :group 'convenience)

(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))
(setq package-archive-priorities '(("gnu" . 10) ("nongnu" . 8) ("melpa" . 5)))

(defconst ed-required-packages
  '(vertico orderless marginalia consult embark embark-consult corfu cape
    scala-mode powershell yaml-mode markdown-mode magit)
  "External packages required by the committed ed configuration.")

(defvar ed--installed-packages-this-startup nil
  "Non-nil when ed installed at least one package during this startup.")

(unless package-archive-contents
  (condition-case err
      (package-refresh-contents)
    (error
     (display-warning
      'ed
      (format "Package archive refresh failed: %s" (error-message-string err))
      :warning))))

;; A use-package :init form runs before its package is required. On a truly
;; clean profile that can call an autoload before it exists, so first-run
;; bootstrap is explicit and finishes before any package-dependent form runs.
(defun ed--install-package-with-retry (package)
  "Install PACKAGE, retrying transient archive failures up to three times."
  (let ((attempt 0)
        last-error)
    (while (and (not (package-installed-p package)) (< attempt 3))
      (setq attempt (1+ attempt))
      (message "ed: installing first-run package %s (attempt %d/3)..."
               package attempt)
      (condition-case err
          (progn
            (package-install package)
            (setq ed--installed-packages-this-startup t))
        (error
         (setq last-error (error-message-string err))
         (message "ed: package %s attempt %d failed: %s"
                  package attempt last-error)
         (when (< attempt 3)
           (sleep-for (* attempt 2))))))
    (unless (package-installed-p package)
      (error
       "ed could not install required package %s after 3 attempts: %s. Check the network and restart ed"
       package last-error))))

(dolist (package ed-required-packages)
  (unless (package-installed-p package)
    (ed--install-package-with-retry package)))

;; Package byte compilation can create a *Warnings* window on the first run.
;; Keep that diagnostic buffer, but do not let it replace the requested file.
(defun ed--dismiss-installation-warnings ()
  "Keep first-run compiler warnings available without letting them steal the frame."
  (when ed--installed-packages-this-startup
    (dolist (name '("*Warnings*" "*Compile-Log*"))
      (when-let ((buffer (get-buffer name)))
        (delete-windows-on buffer)
        (bury-buffer buffer)))))
(add-hook 'emacs-startup-hook #'ed--dismiss-installation-warnings 100)

(require 'use-package)
(setq use-package-always-ensure t
      use-package-expand-minimally t)

(setq modus-themes-italic-constructs t
      modus-themes-bold-constructs nil
      modus-themes-mixed-fonts t
      modus-themes-org-blocks 'gray-background
      ;; quiet, GitHub-ish syntax rather than a rainbow
      modus-themes-prompts '(bold)
      modus-themes-common-palette-overrides
      '((fringe unspecified)
        (comment fg-dim)
        (string green-cooler)))
(load-theme 'modus-operandi :no-confirm)

(defvar ed-cache-dir
  (file-name-as-directory
   (expand-file-name "emacs-ed"
                     (or (getenv "LOCALAPPDATA") temporary-file-directory)))
  "Local, non-synced cache directory (mirrors early-init.el).")

(let ((backups (expand-file-name "backups/" ed-cache-dir))
      (autos   (expand-file-name "auto-save/" ed-cache-dir)))
  (make-directory backups t)
  (make-directory autos t)
  (setq backup-directory-alist         `(("." . ,backups))
        auto-save-file-name-transforms `((".*" ,autos t))
        lock-file-name-transforms      `((".*" ,autos t))
        make-backup-files t
        backup-by-copying t
        delete-old-versions t
        version-control t
        kept-new-versions 6
        kept-old-versions 2))

;; Trim trailing whitespace only in code, never in prose formats.
(add-hook 'prog-mode-hook
          (lambda ()
            (add-hook 'before-save-hook #'delete-trailing-whitespace nil t)))

;; Remember point positions and minibuffer history outside the repository.
(setq save-place-file (expand-file-name "places" ed-cache-dir)
      savehist-file (expand-file-name "history" ed-cache-dir)
      recentf-save-file (expand-file-name "recentf" ed-cache-dir)
      bookmark-default-file (expand-file-name "bookmarks" ed-cache-dir)
      project-list-file (expand-file-name "projects" ed-cache-dir)
      tramp-persistency-file-name (expand-file-name "tramp" ed-cache-dir)
      url-configuration-directory (expand-file-name "url/" ed-cache-dir)
      org-id-locations-file (expand-file-name "org-id-locations" ed-cache-dir)
      recentf-max-saved-items 200)
(save-place-mode 1)
(savehist-mode 1)
(recentf-mode 1)

;; Reload files changed on disk; friendlier duplicate buffer names.
(setq global-auto-revert-non-file-buffers t
      auto-revert-remote-files nil)
(global-auto-revert-mode 1)
(require 'uniquify)
(setq uniquify-buffer-name-style 'forward)

;; Quality-of-life defaults.
(setq inhibit-startup-screen t
      initial-scratch-message nil
      use-short-answers t
      ring-bell-function 'ignore
      sentence-end-double-space nil
      create-lockfiles t)
(delete-selection-mode 1)         ; typing replaces the active region (modern)
(global-so-long-mode 1)           ; stay responsive in huge/minified files

;; Precise, modern trackpad/wheel scrolling; keep old keyboard scroll sane too.
(when (fboundp 'pixel-scroll-precision-mode)
  (pixel-scroll-precision-mode 1))
(setq scroll-conservatively 101
      scroll-margin 2
      scroll-preserve-screen-position t)

;; Select a readable monospaced font and explicit Windows Unicode fallbacks.
(defun ed-apply-fonts (&optional frame)
  "Apply the preferred text, symbol, and emoji fonts to FRAME."
  (with-selected-frame (or frame (selected-frame))
    (when (display-graphic-p)
      (catch 'done
        (dolist (family '("Cascadia Mono" "Cascadia Code" "JetBrains Mono"
                          "Consolas" "Fira Code"))
          (when (find-font (font-spec :family family))
            (set-face-attribute 'default nil :family family :height 140)
            (throw 'done family))))
      (when (find-font (font-spec :family "Segoe UI Symbol"))
        (set-fontset-font t 'symbol (font-spec :family "Segoe UI Symbol") nil 'append))
      (when (find-font (font-spec :family "Segoe UI Emoji"))
        (set-fontset-font t 'emoji (font-spec :family "Segoe UI Emoji") nil 'prepend)))))

(ed-apply-fonts)
(add-hook 'after-make-frame-functions #'ed-apply-fonts)

(when (and (boundp 'battery-status-function) battery-status-function)
  (setq battery-mode-line-format " [\U0001F50B %p%%]")
  (display-battery-mode 1))

;; Programming-buffer niceties.
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'prog-mode-hook #'electric-pair-local-mode)
(add-hook 'prog-mode-hook
          (lambda () (setq-local show-trailing-whitespace t)))
(setq-default indicate-empty-lines nil)  ; keep prose/terminals clean
(column-number-mode 1)
(show-paren-mode 1)
(setq show-paren-context-when-offscreen 'child-frame)

;; Discoverability: which-key is built in on Emacs 30.
(when (fboundp 'which-key-mode) (which-key-mode 1))

;; Handy built-ins that don't touch default bindings' meaning.
(winner-mode 1)      ; C-c <left>/<right> to undo/redo window layouts
(repeat-mode 1)      ; repeat map-able commands without the prefix
(when (fboundp 'editorconfig-mode) (editorconfig-mode 1))

(use-package vertico
  :init (vertico-mode 1)
  :config (setq vertico-cycle t))

(use-package orderless
  :config
  (setq completion-styles '(orderless basic)
        completion-category-overrides '((file (styles basic partial-completion)))))

(use-package marginalia
  :init (marginalia-mode 1))

(use-package consult
  :bind (;; non-default keys only - defaults (C-s isearch, C-x b, M-g g) kept
         ("C-c b" . consult-buffer)
         ("C-c l" . consult-line)
         ("C-c i" . consult-imenu)
         ("C-c r" . consult-ripgrep)
         ("C-c f" . consult-find)
         ("C-c y" . consult-yank-pop))
  :config
  (setq consult-narrow-key "<"))

(use-package embark
  :bind (("C-." . embark-act)
         ("C-;" . embark-dwim)))

(use-package embark-consult
  :after (embark consult))

(use-package corfu
  :init (global-corfu-mode 1)
  :config
  (setq corfu-auto t
        corfu-auto-prefix 2
        corfu-auto-delay 0.15
        corfu-cycle t
        corfu-quit-no-match 'separator)
  
  ;; Shell completion backends may invoke external helper commands.
  ;; Do not run them automatically merely because text was typed.
  (add-hook 'eshell-mode-hook
            (lambda ()
              (setq-local corfu-auto nil)))
  
  (when (fboundp 'corfu-popupinfo-mode)
    (corfu-popupinfo-mode 1)))       ; docs beside the candidate

(use-package cape
  :init
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-dabbrev))

(global-set-key (kbd "C-x C-b") #'ibuffer)

;; Eglot is loaded lazily and NEVER auto-started. No mode hook calls it, so
  ;; merely opening a .cs/.scala/.ps1/etc. file will not launch any server.
  (with-eval-after-load 'eglot
    ;; If you DO start Eglot manually, never let it reformat your buffer on save.
    (add-hook 'eglot-managed-mode-hook
              (lambda ()
                (remove-hook 'before-save-hook #'eglot-format-buffer t)))
    ;; Concrete server programs, used only when you start Eglot yourself.
    (let ((cs (cond ((executable-find "csharp-ls")  '("csharp-ls"))
                    ((executable-find "OmniSharp")   '("OmniSharp" "-lsp"))
                    ((executable-find "omnisharp")   '("omnisharp" "-lsp")))))
      (when cs
        (add-to-list 'eglot-server-programs (cons 'csharp-mode cs))
        (when (fboundp 'csharp-ts-mode)
          (add-to-list 'eglot-server-programs (cons 'csharp-ts-mode cs)))))
    (when (executable-find "metals")
      (add-to-list 'eglot-server-programs '((scala-mode scala-ts-mode) "metals"))))

  (defun ed-eglot-start ()
    "Manually start Eglot (LSP) in the current buffer.
LSP is intentionally never started automatically in this config; invoke
this only when you explicitly want language-server features here."
    (interactive)
    (require 'eglot)
    (call-interactively #'eglot))

(use-package scala-mode
  :interpreter ("scala" . scala-mode))

(use-package powershell
  :commands (powershell-mode)
  :mode (("\\.ps1\\'"  . powershell-mode)
         ("\\.psm1\\'" . powershell-mode)
         ("\\.psd1\\'" . powershell-mode)))

;; JSON via built-in mode.
(add-to-list 'auto-mode-alist '("\\.json\\'" . js-json-mode))

(use-package yaml-mode
  :mode ("\\.ya?ml\\'"))

(use-package markdown-mode
  :mode ("\\.md\\'" "\\.markdown\\'")
  :config (setq markdown-fontify-code-blocks-natively t))

(require 'generic-x)

(define-generic-mode ed-kql-mode
  '("//")                                   ; line comments
  '("let" "where" "project" "project-away" "project-rename" "summarize"
    "extend" "join" "kind" "inner" "outer" "leftouter" "rightouter"
    "union" "order" "sort" "by" "asc" "desc" "take" "limit" "top"
    "distinct" "count" "countif" "sum" "sumif" "avg" "min" "max" "dcount"
    "make-series" "mv-expand" "mv-apply" "parse" "parse-where" "evaluate"
    "render" "range" "print" "as" "on" "and" "or" "not" "in" "has" "hasprefix"
    "hassuffix" "contains" "startswith" "endswith" "between" "matches" "regex"
    "ago" "now" "datetime" "timespan" "bin" "floor" "case" "iff" "iif"
    "isnull" "isnotnull" "isempty" "isnotempty" "toscalar" "todynamic"
    "tostring" "tolong" "toint" "todouble" "tolower" "toupper" "strcat"
    "split" "substring" "materialize" "invoke" "find" "search")
  '(("\\b[0-9]+\\.?[0-9]*\\b" . font-lock-constant-face)
    ("\"[^\"]*\"" . font-lock-string-face))
  '("\\.kql\\'" "\\.csl\\'" "\\.kusto\\'")
  nil
  "Simple generic major mode for Kusto Query Language (KQL) files.")

(use-package magit
  :bind ("C-x g" . magit-status)
  :config (setq magit-diff-refine-hunk 'all))

(require 'eshell)
(setq eshell-directory-name (expand-file-name "eshell/" ed-cache-dir)
      eshell-history-file-name (expand-file-name "history" eshell-directory-name)
      eshell-history-size 5000
      eshell-hist-ignoredups t
      eshell-cmpl-ignore-case t
      eshell-scroll-to-bottom-on-input 'this)

;; 1) Startup: land in an Eshell in the directory ed launched from, but only
;;    when the user did not pass any file to open.
(defvar ed-start-dir nil
  "Directory supplied by the ed launcher.")
(defvar ed-launch-opened-file nil
  "Non-nil when the ed launcher supplied a file argument.")

(defun ed--open-startup-eshell ()
  (unless ed-launch-opened-file
    (let ((default-directory (or ed-start-dir default-directory)))
      (eshell))))
(add-hook 'emacs-startup-hook #'ed--open-startup-eshell)

;; 2) VS Code-style bottom terminal toggle on C-` (and C-c t as a safe alias
;;    for keyboard layouts where backtick is a dead key).
(defcustom ed-eshell-buffer-name "*ed-eshell*"
  "Dedicated buffer name for the toggling bottom Eshell."
  :type 'string :group 'ed)
(defcustom ed-eshell-height-ratio 0.28
  "Fraction of the frame height used by the bottom Eshell pane."
  :type 'number :group 'ed)

(defun ed--eshell-buffer ()
  "Return (creating if needed) the dedicated Eshell buffer, without stealing focus."
  (let ((eshell-buffer-name ed-eshell-buffer-name))
    (or (get-buffer ed-eshell-buffer-name)
        (save-window-excursion (eshell) (get-buffer ed-eshell-buffer-name)))))

(defun ed-eshell-toggle ()
  "Toggle a bottom Eshell pane at the frame's base, VS Code style."
  (interactive)
  (let* ((buf (ed--eshell-buffer))
         (win (get-buffer-window buf (selected-frame))))
    (if (window-live-p win)
        (condition-case _ (delete-window win) (error (bury-buffer buf)))
      (let* ((height (max window-min-height
                          (round (* (frame-height) ed-eshell-height-ratio))))
             (win (display-buffer-in-side-window
                   buf `((side . bottom) (window-height . ,height)))))
        (when (window-live-p win)
          (select-window win)
          (unless (eq major-mode 'eshell-mode) (eshell-mode)))))))

(global-set-key (kbd "C-`") #'ed-eshell-toggle)
(global-set-key (kbd "C-c t") #'ed-eshell-toggle)

(defun ed--refresh-focus-modeline ()
  "Dim the mode-line a touch when no Emacs frame has focus."
  (ignore-errors
    (let ((focused (seq-some #'frame-focus-state (frame-list))))
      (set-face-attribute
       'mode-line nil :background
       (modus-themes-get-color-value (if focused 'bg-mode-line-active
                                       'bg-mode-line-inactive))))))
(when (fboundp 'modus-themes-get-color-value)
  (add-function :after after-focus-change-function
                #'ed--refresh-focus-modeline))

(defun ed-reload-config ()
  "Re-tangle and load init-config.org."
  (interactive)
  (let* ((init-dir (file-name-directory (or user-init-file default-directory)))
         (org-file (expand-file-name "init-config.org" init-dir)))
    (org-babel-load-file org-file)
    (message "ed: configuration reloaded.")))

(defun ed-open-config ()
  "Open the literate configuration for editing."
  (interactive)
  (let ((init-dir (file-name-directory (or user-init-file default-directory))))
    (find-file (expand-file-name "init-config.org" init-dir))))

(defun ed-copy-file-as-markdown ()
  "Copy the current file as a fenced Markdown block (handy for pasting to an LLM)."
  (interactive)
  (unless buffer-file-name
    (user-error "This buffer does not visit a file"))
  (let* ((path (file-truename buffer-file-name))
         (ext  (or (file-name-extension path) "text"))
         (body (buffer-substring-no-properties (point-min) (point-max))))
    (kill-new (format "%s:\n```%s\n%s\n```" path ext body))
    (message "Copied %s as Markdown" path)))

(defun ed-insert-date ()
  "Insert the current date as YYYY-MM-DD."
  (interactive)
  (insert (format-time-string "%Y-%m-%d")))

(defun ed-insert-file-name ()
  "Insert the current buffer's file name at point."
  (interactive)
  (insert (if buffer-file-name
              (file-name-nondirectory buffer-file-name)
            "")))

(defun ed-copy-full-path ()
  "Copy the current buffer's full path to the kill ring."
  (interactive)
  (if buffer-file-name
      (progn (kill-new (file-truename buffer-file-name))
             (message "Copied %s" buffer-file-name))
    (user-error "This buffer does not visit a file")))
