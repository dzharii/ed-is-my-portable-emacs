;;; init.el --- ed entry point  -*- lexical-binding: t; -*-

(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8)
(set-default-coding-systems 'utf-8)
(setq locale-coding-system 'utf-8
      selection-coding-system 'utf-8
      default-buffer-file-coding-system 'utf-8)

(let* ((init-dir (file-name-as-directory
                  (or (and load-file-name (file-name-directory load-file-name))
                      user-emacs-directory)))
       (generated-file (expand-file-name "init-config.el" init-dir))
       (source-file (expand-file-name "init-config.org" init-dir)))
  (cond
   ((file-readable-p generated-file)
    (load generated-file nil 'nomessage))
   ((file-readable-p source-file)
    (require 'org)
    (org-babel-load-file source-file))
   (t
    (user-error "No init-config.el or init-config.org found in %s" init-dir))))

(let ((custom-dir (if (boundp 'ed-cache-dir)
                      ed-cache-dir
                    user-emacs-directory)))
  (make-directory custom-dir t)
  (setq custom-file (expand-file-name "custom.el" custom-dir))
  (load custom-file 'noerror 'nomessage))

;;; init.el ends here
