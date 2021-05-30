;;setting up developer packages 
(require 'package)
(setq package-archives
      '(("melpa" . "https://melpa.org/packages/")
        ("gnu" . "https://elpa.gnu.org/packages/")
        ("org" . "http://orgmode.org/elpa/")))
;; Comment/uncomment this line to enable MELPA Stable if desired.  See `package-archive-priorities`
;; and `package-pinned-packages`. Most users will not need or want to do this.
(add-to-list 'package-archives '("melpa-stable" . "https://stable.melpa.org/packages/") t)
(package-initialize)
;use M-x package-refresh-contents, this will update to current packages

;prevent splash screen
(setq inhibit-splash-screen t)

;on startup run a eshell, 
(setq inhibit-startup-message t
      initial-buffer-choice 'eshell)
;use find-file <filename>, to open in e buffer

;; making buffers more acessable
(ido-mode 'buffers)
(setq ido-separator "||")
(global-set-key [C-tab] 'switch-to-buffer)

;; getting rid of extra find file keystrokes
(global-set-key "\C-f" 'find-file)

;; transparent background 
(set-frame-parameter (selected-frame) 'alpha '(85 . 85))

;; athstetics
(if (display-graphic-p)
    (setq initial-frame-alist
          '(
            (tool-bar-lines . 0)
            (width . 106)
            (height . 60)
	    (foreground-color . "#f8f8f2")
            (background-color . "#282a36")
            (left . 50)
            (top . 50)))
(setq initial-frame-alist '( (tool-bar-lines . 0))))
(setq default-frame-alist initial-frame-alist)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(emmet-mode eglot lsp-mode ## transient jest dracula-theme auctex)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )


;;Clang with eglot the best lsp framework
(require 'eglot)
(global-set-key (kbd "C-<return>")'completion-at-point)

;;server hooks for langues
;; https://clangd.llvm.org/installation.html
(add-to-list 'eglot-server-programs '((c++-mode c-mode) "clangd"))
(add-hook 'c-mode-hook 'eglot-ensure)
(add-hook 'c++-mode-hook 'eglot-ensure)


;; fixing ctrl z in windows
(if window-system (global-set-key "\C-z" 'advertised-undo))

;; some good short cuts
(global-set-key "\C-s" 'save-buffer);
(global-set-key "\C-v" 'yank)
