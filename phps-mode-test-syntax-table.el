;;; phps-mode-test-syntax-table.el --- Tests for syntax-table -*- lexical-binding: t -*-

;; Copyright (C) 2019 Christian Johansson

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Spathoftware Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.


;;; Commentary:


;; Run from terminal make functions-test


;;; Code:


(autoload 'phps-mode-test-with-buffer "phps-mode-test")
(autoload 'phps-mode-functions-verbose "phps-mode-functions")
(autoload 'phps-mode-functions-indent-line "phps-mode-functions")
(autoload 'phps-mode-functions-get-lines-indent "phps-mode-functions")
(autoload 'phps-mode-functions-get-imenu "phps-mode-functions")
(autoload 'phps-mode-test-hash-to-list "phps-mode-test")
(autoload 'should "ert")

(defun phps-mode-test-syntax-table-quote-region ()
  "Test double quotes, single quotes, curly bracket, square bracket, round bracket, back-quotes on regions."

  (phps-mode-test-with-buffer
   "<?php\n$var = abc;"
   "Double quotes around region"
   (goto-char 14)
   (push-mark nil t t)
   (goto-char 17)
   (execute-kbd-macro (kbd "\""))
   (let ((buffer-contents (buffer-substring-no-properties (point-min) (point-max))))
     (should (equal buffer-contents "<?php\n$var = \"abc\";"))))

  (phps-mode-test-with-buffer
   "<?php\n$var = abc;"
   "Single-quotes brackets around region"
   (goto-char 14)
   (push-mark nil t t)
   (goto-char 17)
   (execute-kbd-macro (kbd "'"))
   (let ((buffer-contents (buffer-substring-no-properties (point-min) (point-max))))
     (should (equal buffer-contents "<?php\n$var = 'abc';"))))

  (phps-mode-test-with-buffer
   "<?php\n$var = abc;"
   "Round brackets around region"
   (goto-char 14)
   (push-mark nil t t)
   (goto-char 17)
   (execute-kbd-macro (kbd "("))
   (let ((buffer-contents (buffer-substring-no-properties (point-min) (point-max))))
     (should (equal buffer-contents "<?php\n$var = (abc);"))))

  (phps-mode-test-with-buffer
   "<?php\n$var = abc;"
   "Square brackets around region"
   (goto-char 14)
   (push-mark nil t t)
   (goto-char 17)
   (execute-kbd-macro (kbd "["))
   (let ((buffer-contents (buffer-substring-no-properties (point-min) (point-max))))
     (should (equal buffer-contents "<?php\n$var = [abc];"))))

  (phps-mode-test-with-buffer
   "<?php\n$var = abc;"
   "Curly brackets around region"
   (goto-char 14)
   (push-mark nil t t)
   (goto-char 17)
   (execute-kbd-macro (kbd "{"))
   (let ((buffer-contents (buffer-substring-no-properties (point-min) (point-max))))
     (should (equal buffer-contents "<?php\n$var = {abc};"))))

  (phps-mode-test-with-buffer
   "<?php\n$var = abc;"
   "Backquotes brackets around region"
   (goto-char 14)
   (push-mark nil t t)
   (goto-char 17)
   (execute-kbd-macro (kbd "`"))
   (let ((buffer-contents (buffer-substring-no-properties (point-min) (point-max))))
     (should (equal buffer-contents "<?php\n$var = `abc`;"))))
  

  )

(defun phps-mode-test-syntax-table ()
  "Run test."
  (phps-mode-test-syntax-table-quote-region))

(phps-mode-test-syntax-table)


(provide 'phps-mode-test-syntax-table)

;;; phps-mode-test-syntax-table.el ends here