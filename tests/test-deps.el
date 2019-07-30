;;; test-deps.el --- Test package-build  -*- lexical-binding:t -*-

;; Copyright (C) 2019 The Authors of test-deps.el

;; Author: dickmao <github id: dickmao>
;; Version: 0
;; Keywords: tools

;; This file is NOT part of GNU Emacs.
;; However, it is distributed under the same license.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

(require 'ert)
(require 'package-build)

(defconst test-deps-directory
  (concat default-directory (file-name-as-directory "tests") (file-name-as-directory "test-deps.dir"))
  "Working directory for tests.")

(defsubst test-deps-recipe (pkgname)
  "Return canonical location of recipe PKGNAME on github."
  (format "https://raw.githubusercontent.com/melpa/melpa/master/recipes/%s" pkgname))

(defun test-deps--retrieve-recipe (pkgname)
  "Return recipe object for PKGNAME."
  (with-current-buffer (url-retrieve-synchronously (test-deps-recipe pkgname) t t)
    (goto-char url-http-end-of-headers)
    (skip-chars-forward "\r\n")
    (let ((recipe (eval (car (read-from-string
                              (format "(quote %s)"
                                      (buffer-substring (point) (point-max))))))))
      (package-recipe--validate recipe (symbol-name (car recipe)))
      (prog1 recipe
        (kill-buffer)))))

(defun test-deps--rewrite-recipe (recipe &rest args)
  "Write RECIPE back out to file with ARGS."
  (unless (file-exists-p package-build-recipes-dir)
    (make-directory package-build-recipes-dir))
  (let ((name (car recipe))
        (plist (cdr recipe)))
    (cl-loop for (k v) on args by (function cddr)
             do (setq plist (plist-put plist k v)))
    (with-temp-buffer
      (insert (format "%S\n" (cons name plist)))
      (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) t)))
        (write-file (concat package-build-recipes-dir (symbol-name name)))))))

(defun test-deps--semver (pkgname)
  "Return the current Version (not the Package-Version) of PKGNAME."
  (let ((package-file (locate-library (concat pkgname ".el")))
        package-version)
    (with-temp-buffer
      (insert-file-contents package-file)
      (goto-char (point-min))
      (when (re-search-forward " Version:\\s-*\\(\\S-+\\)" nil t)
        (setq package-version (match-string 1))))
    (message "%s version: %s" pkgname package-version)
    package-version))

(defun test-deps--install-file (pkgname)
  "Discern the appropriate installer for PKGNAME."
  (car (cl-mapcan (lambda (x)
                    (file-expand-wildcards
                     (concat package-build-archive-dir pkgname x)))
                  '("*.el" "*.tar"))))

(defun test-deps--install (pkgname &rest args)
  "Install PKGNAME abridged by ARGS.  Return semantic version installed."
  (apply #'test-deps--rewrite-recipe (test-deps--retrieve-recipe pkgname) args)
  (package-build-archive pkgname)
  (package-install-file (test-deps--install-file pkgname))
  (test-deps--semver pkgname))

(ert-deftest test-deps-remain-broken-under-semver ()
  "Document the dependency management bug."
  (package-initialize)
  (add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/"))
  (package-refresh-contents)
  (unless (file-exists-p test-deps-directory)
    (make-directory test-deps-directory))
  (apply #'custom-set-variables
         `(package-user-dir ,(let ((user-emacs-directory test-deps-directory))
                               (locate-user-emacs-file "elpa")))
         (mapcar (lambda (x) `(,(intern (concat "package-build-" (car x) "-dir"))
                               ,(concat test-deps-directory (file-name-as-directory
                                                        (or (cdr x) (car x))))))
                 '(("working") ("archive" . "packages") ("recipes"))))
  (should (string= "2.14.1" (test-deps--install "dash" :commit "a74f4cf")))
  (should (string= "1.0.0" (test-deps--install "jeison" :commit "66e276c")))
  (should (string= "2.14.1" (test-deps--semver "dash"))) ;; erroneously did not update

  ;; now use datetime versioning
  (let ((install-file (test-deps--install-file "jeison")))
    (find-file install-file)
    (re-search-forward "dash \"[0-9.]+\"" nil t)
    (replace-match "dash \"20190424\"" nil nil)
    (save-buffer)
    (kill-buffer)
    (package-install-file install-file))
  (should (string= "2.16.0" (test-deps--semver "dash"))))

(provide 'test-deps)
;;; test-deps.el ends here
