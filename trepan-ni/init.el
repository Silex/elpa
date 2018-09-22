;; Copyright (C) 2015-2016, 2018 Rocky Bernstein <rocky@gnu.org>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; "node inspect" debugger

(eval-when-compile (require 'cl-lib))   ;For setf.

(require 'realgud)
(require 'realgud-lang-js)
(require 'ansi-color)

(defvar realgud:trepan-ni-pat-hash)
(declare-function make-realgud-loc-pat (realgud-loc))

(defvar realgud:trepan-ni-pat-hash (make-hash-table :test 'equal)
  "Hash key is the what kind of pattern we want to match:
backtrace, prompt, etc.  The values of a hash entry is a
realgud-loc-pat struct")

;; before a command prompt.
;; For example:
;;   break in /home/indutny/Code/git/indutny/myscript.js:1
(setf (gethash "loc" realgud:trepan-ni-pat-hash)
      (make-realgud-loc-pat
       :regexp (format
		"\\(?:%s\\)*\\(?:break\\|exception\\|frame change\\) in %s:%s"
		realgud:js-term-escape "\\([^:]+\\)"
		realgud:regexp-captured-num)
       :file-group 1
       :line-group 2))

;; Regular expression that describes a trepan-ni command prompt
;; For example:
;;   debug>
(setf (gethash "prompt" realgud:trepan-ni-pat-hash)
      (make-realgud-loc-pat
       :regexp (format "^\\(?:%s\\)*(trepan-ni) " realgud:js-term-escape)
       ))

;; realgud-loc-pat that describes a "breakpoint set" line
;; For example:
;;  Breakpoint 1 set in file /tmp/gcd.js, line 2.
;;  Breakpoint set in file /usr/lib/nodejs/module.js [module.js], line 380.
(setf (gethash "brkpt-set" realgud:trepan-ni-pat-hash)
      (make-realgud-loc-pat
       :regexp (format "^Breakpoint %s set in file %s, line %s.\n"
		       realgud:regexp-captured-num
		       realgud:trepanjs-file-regexp
		       realgud:regexp-captured-num)
       :num 1
       :file-group 2
       :line-group 3))


;; Regular expression that describes a V8 backtrace line.
;; For example:
;;    at repl:1:7
;;    at Interface.controlEval (/src/external-vcs/github/trepanjs/lib/interface.js:352:18)
;;    at REPLServer.b [as eval] (domain.js:183:18)
(setf (gethash "lang-backtrace" realgud:trepan-ni-pat-hash)
  realgud:js-backtrace-loc-pat)

;; Regular expression that describes a debugger "delete" (breakpoint)
;; response.
;; For example:
;;   Removed 1 breakpoint(s).
(setf (gethash "brkpt-del" realgud:trepan-ni-pat-hash)
      (make-realgud-loc-pat
       :regexp (format "^Removed %s breakpoint(s).\n"
		       realgud:regexp-captured-num)
       :num 1))


(defconst realgud:trepan-ni-frame-start-regexp  "\\(?:^\\|\n\\)\\(?:##\|->\)")
(defconst realgud:trepan-ni-frame-num-regexp    realgud:regexp-captured-num)
(defconst realgud:trepan-ni-frame-module-regexp "[^ \t\n]+")
(defconst realgud:trepan-ni-frame-file-regexp   "[^ \t\n]+")

;; Regular expression that describes a trepan-ni location generally shown
;; Regular expression that describes a debugger "backtrace" command line.
;; For example:
;; #0 module.js:380:17
;; #1 dbgtest.js:3:9
;; #2 Module._compile module.js:456:26
;; #3 Module._extensions..js module.js:474:10
;; #4 Module.load module.js:356:32
;; #5 Module._load module.js:312:12
;; #6 Module.runMain module.js:497:10
; ;#7 timers.js:110:15
(setf (gethash "debugger-backtrace" realgud:trepan-ni-pat-hash)
      (make-realgud-loc-pat
       :regexp 	(concat realgud:trepan-ni-frame-start-regexp
			realgud:trepan-ni-frame-num-regexp " "
			"\\(?:" realgud:trepan-ni-frame-module-regexp " \\)?"
			"\\(" realgud:trepan-ni-frame-file-regexp "\\)"
			":"
			realgud:regexp-captured-num
			":"
			realgud:regexp-captured-num
			)
       :num 1
       :file-group 2
       :line-group 3
       :char-offset-group 4))

(defconst realgud:trepan-ni-debugger-name "trepan-ni" "Name of debugger")

;; Regular expression that for a termination message.
(setf (gethash "termination" realgud:trepan-ni-pat-hash)
       "^trepan-ni: That's all, folks!\n")

(setf (gethash "font-lock-keywords" realgud:trepan-ni-pat-hash)
      '(
	;; The frame number and first type name, if present.
	;; E.g. ->0 (anonymous) tmp/gcd.js:2:11
	;;      --^-
	("^\\(->\\|##\\)\\([0-9]+\\) "
	 (2 realgud-backtrace-number-face))

	;; File name.
	;; E.g. ->0 (anonymous) tmp/gcd.js:2:11
	;;          ------------^^^^^^^^^^
	("\\(?:.*\\)[ \t]+\\([^:]+\\):"
	 (2 realgud-file-name-face))

	;; Line Number
	;; E.g. ->0 (anonymous) tmp/gcd.js:2:11
	;;                                 ^
	;; Line number.
	("\\([0-9]+\\)"
	 (1 realgud-line-number-face))
	))

(setf (gethash "trepan-ni" realgud-pat-hash)
      realgud:trepan-ni-pat-hash)

;;  Prefix used in variable names (e.g. short-key-mode-map) for
;; this debugger

(setf (gethash "trepan-ni" realgud:variable-basename-hash)
      "realgud:trepan-ni")

(defvar realgud:trepan-ni-command-hash (make-hash-table :test 'equal)
  "Hash key is command name like 'finish' and the value is
  the trepan-ni command to use, like 'out'")

(setf (gethash realgud:trepan-ni-debugger-name
	       realgud-command-hash)
      realgud:trepan-ni-command-hash)

(setf (gethash "backtrace"  realgud:trepan-ni-command-hash) "backtrace")
(setf (gethash "break"      realgud:trepan-ni-command-hash)
      "setBreakpoint('%X',%l)")
(setf (gethash "continue"   realgud:trepan-ni-command-hash) "cont")
(setf (gethash "kill"       realgud:trepan-ni-command-hash) "kill")
(setf (gethash "quit"       realgud:trepan-ni-command-hash) "")
(setf (gethash "finish"     realgud:trepan-ni-command-hash) "out")
(setf (gethash "shell"      realgud:trepan-ni-command-hash) "repl")
(setf (gethash "eval"       realgud:trepan-ni-command-hash) "eval('%s')")

;; We need aliases for step and next because the default would
;; do step 1 and trepan-ni doesn't handle this. And if it did,
;; it would probably look like step(1).
(setf (gethash "step"       realgud:trepan-ni-command-hash) "step")
(setf (gethash "next"       realgud:trepan-ni-command-hash) "next")

(setf (gethash "up"         realgud:trepan-ni-command-hash) "up(%p)")
(setf (gethash "down"       realgud:trepan-ni-command-hash) "down(%p)")
(setf (gethash "frame"      realgud:trepan-ni-command-hash) "frame(%p)")

;; Unsupported features:
(setf (gethash "jump"       realgud:trepan-ni-command-hash) "*not-implemented*")


(setf (gethash "trepan-ni" realgud-command-hash) realgud:trepan-ni-command-hash)
(setf (gethash "trepan-ni" realgud-pat-hash) realgud:trepan-ni-pat-hash)

(provide-me "realgud:trepan-ni-")