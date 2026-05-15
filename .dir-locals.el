((nil
  (indent-tabs-mode . nil))
 (makefile-mode
  (indent-tabs-mode . t)
  (outline-regexp . "#\\(#+\\)")
  (mode . outline-minor))
 (emacs-lisp-mode
  (lisp-indent-local-overrides . ((cond . 0) (interactive . 0)))
  (mode . checkdoc-minor))
 (git-commit-mode
  (git-commit-major-mode . git-commit-elisp-text-mode)))
