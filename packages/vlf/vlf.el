;;; vlf.el --- View Large Files  -*- lexical-binding: t -*-

;; Copyright (C) 2006, 2012-2014 Free Software Foundation, Inc.

;; Version: 1.2
;; Keywords: large files, utilities
;; Maintainer: Andrey Kotlarski <m00naticus@gmail.com>
;; Authors: 2006 Mathias Dahl <mathias.dahl@gmail.com>
;;          2012 Sam Steingold <sds@gnu.org>
;;          2013-2014 Andrey Kotlarski <m00naticus@gmail.com>
;; URL: https://github.com/m00natic/vlfi

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:
;; This package provides the M-x vlf command, which visits part of a
;; large file without loading the entire file.
;; The buffer uses VLF mode, which defines several commands for
;; moving around, searching and editing selected part of file.

;; This package was inspired by a snippet posted by Kevin Rodgers,
;; showing how to use `insert-file-contents' to extract part of a
;; file.

;;; Code:

;;;###autoload
(require 'vlf-integrate)

(require 'vlf-base)

(defcustom vlf-batch-size 1024
  "Defines how large each batch of file data is (in bytes)."
  :group 'vlf
  :type 'integer)
(put 'vlf-batch-size 'permanent-local t)

;;; Keep track of file position.
(defvar vlf-start-pos 0
  "Absolute position of the visible chunk start.")
(put 'vlf-start-pos 'permanent-local t)

(defvar vlf-end-pos 0 "Absolute position of the visible chunk end.")
(put 'vlf-end-pos 'permanent-local t)

(defvar vlf-file-size 0 "Total size of presented file.")
(put 'vlf-file-size 'permanent-local t)

(autoload 'vlf-write "vlf-write" "Write current chunk to file.")
(autoload 'vlf-re-search-forward "vlf-search"
  "Search forward for REGEXP prefix COUNT number of times.")
(autoload 'vlf-re-search-backward "vlf-search"
  "Search backward for REGEXP prefix COUNT number of times.")
(autoload 'vlf-goto-line "vlf-search" "Go to line.")
(autoload 'vlf-occur "vlf-occur"
  "Make whole file occur style index for REGEXP.")
(autoload 'vlf-toggle-follow "vlf-follow"
  "Toggle continuous chunk recenter around current point.")

(defvar vlf-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "n" 'vlf-next-batch)
    (define-key map "p" 'vlf-prev-batch)
    (define-key map " " 'vlf-next-batch-from-point)
    (define-key map "+" 'vlf-change-batch-size)
    (define-key map "-"
      (lambda () "Decrease vlf batch size by factor of 2."
        (interactive)
        (vlf-change-batch-size t)))
    (define-key map "s" 'vlf-re-search-forward)
    (define-key map "r" 'vlf-re-search-backward)
    (define-key map "o" 'vlf-occur)
    (define-key map "[" 'vlf-beginning-of-file)
    (define-key map "]" 'vlf-end-of-file)
    (define-key map "j" 'vlf-jump-to-chunk)
    (define-key map "l" 'vlf-goto-line)
    (define-key map "f" 'vlf-toggle-follow)
    (define-key map "g" 'vlf-revert)
    map)
  "Keymap for `vlf-mode'.")

(defvar vlf-prefix-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-c\C-v" vlf-mode-map)
    map)
  "Prefixed keymap for `vlf-mode'.")

(defmacro vlf-with-undo-disabled (&rest body)
  "Execute BODY with temporarily disabled undo."
  `(let ((undo-list buffer-undo-list))
     (setq buffer-undo-list t)
     (unwind-protect (progn ,@body)
       (setq buffer-undo-list undo-list))))

(define-minor-mode vlf-mode
  "Mode to browse large files in."
  :lighter " VLF"
  :group 'vlf
  :keymap vlf-prefix-map
  (if vlf-mode
      (progn
        (set (make-local-variable 'require-final-newline) nil)
        (add-hook 'write-file-functions 'vlf-write nil t)
        (set (make-local-variable 'revert-buffer-function)
             'vlf-revert)
        (make-local-variable 'vlf-batch-size)
        (set (make-local-variable 'vlf-file-size)
             (vlf-get-file-size buffer-file-truename))
        (set (make-local-variable 'vlf-start-pos) 0)
        (set (make-local-variable 'vlf-end-pos) 0)
        (set (make-local-variable 'vlf-follow-timer) nil)
        (let* ((pos (position-bytes (point)))
               (start (* (/ pos vlf-batch-size) vlf-batch-size)))
          (goto-char (byte-to-position (- pos start)))
          (vlf-move-to-batch start)))
    (kill-local-variable 'revert-buffer-function)
    (vlf-stop-following)
    (when (or (not large-file-warning-threshold)
              (< vlf-file-size large-file-warning-threshold)
              (y-or-n-p (format "Load whole file (%s)? "
                                (file-size-human-readable
                                 vlf-file-size))))
      (kill-local-variable 'require-final-newline)
      (remove-hook 'write-file-functions 'vlf-write t)
      (let ((pos (+ vlf-start-pos (position-bytes (point)))))
        (vlf-with-undo-disabled
         (insert-file-contents buffer-file-name t nil nil t))
        (goto-char (byte-to-position pos)))
      (rename-buffer (file-name-nondirectory buffer-file-name) t))))

;;;###autoload
(defun vlf (file)
  "View Large FILE in batches.
You can customize number of bytes displayed by customizing
`vlf-batch-size'."
  (interactive "fFile to open: ")
  (with-current-buffer (generate-new-buffer "*vlf*")
    (set-visited-file-name file)
    (set-buffer-modified-p nil)
    (vlf-mode 1)
    (switch-to-buffer (current-buffer))))

;; scroll auto batching
(defadvice scroll-up (around vlf-scroll-up
                             activate compile)
  "Slide to next batch if at end of buffer in `vlf-mode'."
  (if (and vlf-mode (pos-visible-in-window-p (point-max)))
      (progn (vlf-next-batch 1)
             (goto-char (point-min)))
    ad-do-it))

(defadvice scroll-down (around vlf-scroll-down
                               activate compile)
  "Slide to previous batch if at beginning of buffer in `vlf-mode'."
  (if (and vlf-mode (pos-visible-in-window-p (point-min)))
      (progn (vlf-prev-batch 1)
             (goto-char (point-max)))
    ad-do-it))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; utilities

(defun vlf-change-batch-size (decrease)
  "Change the buffer-local value of `vlf-batch-size'.
Normally, the value is doubled;
with the prefix argument DECREASE it is halved."
  (interactive "P")
  (setq vlf-batch-size (if decrease
                           (/ vlf-batch-size 2)
                         (* vlf-batch-size 2)))
  (vlf-move-to-batch vlf-start-pos))

(defun vlf-update-buffer-name ()
  "Update the current buffer name."
  (rename-buffer (format "%s(%d/%d)[%s]"
                         (file-name-nondirectory buffer-file-name)
                         (/ vlf-end-pos vlf-batch-size)
                         (/ vlf-file-size vlf-batch-size)
                         (file-size-human-readable vlf-batch-size))
                 t))

(defun vlf-get-file-size (file)
  "Get size in bytes of FILE."
  (or (nth 7 (file-attributes file)) 0))

(defun vlf-verify-size ()
  "Update file size information if necessary and visited file time."
  (unless (verify-visited-file-modtime (current-buffer))
    (setq vlf-file-size (vlf-get-file-size buffer-file-truename))
    (set-visited-file-modtime)))

(defun vlf-insert-file (&optional from-end)
  "Insert first chunk of current file contents in current buffer.
With FROM-END prefix, start from the back."
  (let ((start 0)
        (end vlf-batch-size))
    (if from-end
        (setq start (- vlf-file-size vlf-batch-size)
              end vlf-file-size)
      (setq end (min vlf-batch-size vlf-file-size)))
    (vlf-move-to-chunk start end)))

(defun vlf-beginning-of-file ()
  "Jump to beginning of file content."
  (interactive)
  (vlf-insert-file))

(defun vlf-end-of-file ()
  "Jump to end of file content."
  (interactive)
  (vlf-insert-file t))

(defun vlf-revert (&optional _ignore-auto noconfirm)
  "Revert current chunk.  Ignore _IGNORE-AUTO.
Ask for confirmation if NOCONFIRM is nil."
  (interactive)
  (when (or noconfirm
            (yes-or-no-p (format "Revert buffer from file %s? "
                                 buffer-file-name)))
    (set-buffer-modified-p nil)
    (set-visited-file-modtime)
    (vlf-move-to-chunk-2 vlf-start-pos vlf-end-pos)))

(defun vlf-jump-to-chunk (n)
  "Go to to chunk N."
  (interactive "nGoto to chunk: ")
  (vlf-move-to-batch (* (1- n) vlf-batch-size)))

(defun vlf-no-modifications ()
  "Ensure there are no buffer modifications."
  (if (buffer-modified-p)
      (error "Save or discard your changes first")
    t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; batch movement

(defun vlf-next-batch (append)
  "Display the next batch of file data.
When prefix argument is supplied and positive
 jump over APPEND number of batches.
When prefix argument is negative
 append next APPEND number of batches to the existing buffer."
  (interactive "p")
  (vlf-verify-size)
  (let* ((end (min (+ vlf-end-pos (* vlf-batch-size (abs append)))
                   vlf-file-size))
         (start (if (< append 0)
                    vlf-start-pos
                  (- end vlf-batch-size))))
    (vlf-move-to-chunk start end)))

(defun vlf-prev-batch (prepend)
  "Display the previous batch of file data.
When prefix argument is supplied and positive
 jump over PREPEND number of batches.
When prefix argument is negative
 append previous PREPEND number of batches to the existing buffer."
  (interactive "p")
  (if (zerop vlf-start-pos)
      (error "Already at BOF"))
  (let* ((start (max 0 (- vlf-start-pos (* vlf-batch-size (abs prepend)))))
         (end (if (< prepend 0)
                  vlf-end-pos
                (+ start vlf-batch-size))))
    (vlf-move-to-chunk start end)))

(defun vlf-move-to-batch (start &optional minimal)
  "Move to batch determined by START.
Adjust according to file start/end and show `vlf-batch-size' bytes.
When given MINIMAL flag, skip non important operations."
  (vlf-verify-size)
  (let* ((start (max 0 start))
         (end (min (+ start vlf-batch-size) vlf-file-size)))
    (if (= vlf-file-size end)          ; re-adjust start
        (setq start (max 0 (- end vlf-batch-size))))
    (vlf-move-to-chunk start end minimal)))

(defun vlf-next-batch-from-point ()
  "Display batch of file data starting from current point."
  (interactive)
  (let ((start (+ vlf-start-pos (position-bytes (point)) -1)))
    (vlf-move-to-chunk start (+ start vlf-batch-size)))
  (goto-char (point-min)))

(provide 'vlf)

;;; vlf.el ends here
