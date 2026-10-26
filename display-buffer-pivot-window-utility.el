;;; display-buffer-pivot-window-utility.el --- Small snippets for window management  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/display-buffer-pivot
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; The window test, the split options and the window prompt used by the
;; display action and the window prefix commands.

;;; Code:

(require 'ace-window)
(require 'cl-lib)

(defun display-buffer-pivot-window-utility-cannot-display-p (window)
  "Return non-nil if WINDOW does not take another buffer's display.
That is a window dedicated to its buffer or a side window."
  (or (window-dedicated-p window)
      (window-parameter window 'window-side)))

(defcustom display-buffer-pivot-window-utility-split-maximum 4
  "The number of windows under which a split is preferred over asking.
When fewer windows than this can take a buffer's display, split a new
one with `display-buffer-pop-up-window'; at this number or more, ask
for a window with `ace-window' instead.  `display-buffer-pivot-window-utility-split-p' makes the
test."
  :group 'windows
  :type 'integer)

(defcustom display-buffer-pivot-window-utility-split-maximum-exclude-side t
  "Non-nil to leave side windows out of `display-buffer-pivot-window-utility-split-maximum'."
  :group 'windows
  :type 'boolean)

(defcustom display-buffer-pivot-window-utility-split-maximum-exclude-dedicated t
  "Non-nil to leave dedicated windows out of `display-buffer-pivot-window-utility-split-maximum'."
  :group 'windows
  :type 'boolean)

(defun display-buffer-pivot-window-utility-split-p ()
  "Return non-nil when a split is preferred over asking for a window.
Count the windows `aw-window-list' offers, leaving out the side windows
and dedicated windows that `display-buffer-pivot-window-utility-split-maximum-exclude-side' and
`display-buffer-pivot-window-utility-split-maximum-exclude-dedicated' exclude, and compare the
count with `display-buffer-pivot-window-utility-split-maximum'."
  (let ((count (cl-count-if
                (lambda (window)
                  (and (not (and display-buffer-pivot-window-utility-split-maximum-exclude-side
                                 (window-parameter window 'window-side)))
                       (not (and display-buffer-pivot-window-utility-split-maximum-exclude-dedicated
                                 (window-dedicated-p window)))))
                (aw-window-list))))
    (< count display-buffer-pivot-window-utility-split-maximum)))

(defun display-buffer-pivot-window-utility-choose-display-window (scope ignore-current &optional mode-line)
  "Ask for a window with `aw-select' to display a buffer in.
SCOPE and IGNORE-CURRENT are bound to `aw-scope' and
`aw-ignore-current' for the choice; MODE-LINE is passed to `aw-select'
and defaults to \"Display buffer in window\".

Ask again while the chosen window cannot display the buffer, a window
`display-buffer-pivot-window-utility-cannot-display-p' answers for.  Should the choice return the
window it was told to ignore -- `aw-select' has none other to offer --
choose nothing.

Return the chosen window, or `nil' when SCOPE is nil, in batch, while
the minibuffer is active, when the choice is cancelled, or when no
window was chosen.  Cancelling the choice (C-g) quits the command whose
display it is."
  (when (and scope
             (not noninteractive)
             (not (active-minibuffer-window)))
    (let ((aw-scope scope)
          (aw-ignore-current ignore-current)
          done win)
      (while (and (not done)
                  (setq win (aw-select (or mode-line
                                           "Display buffer in window")))
                  (window-live-p win))
        (cond
         ;; `aw-select' returns the window it was told to ignore when it
         ;; has none other to offer: its branch for one window returns
         ;; `(or (car wnd-list) start-window)' whatever
         ;; `aw-ignore-current' says.  Stop asking and choose nothing.
         ((and aw-ignore-current (eq win (selected-window)))
          (setq done t
                win nil))
         ((display-buffer-pivot-window-utility-cannot-display-p win))
         (t (setq done t))))
      win)))

(defun display-buffer-pivot-window-utility-select-window-post-command (window)
  "Select WINDOW when the current command ends.
The entry that does it is added to `post-command-hook' and removes
itself when it runs, so no later command sees it.  This is the way
`display-buffer' treats a `nil' `post-command-select-window' entry."
  (when (window-live-p window)
    (letrec ((postfun
              (lambda ()
                (when (window-live-p window)
                  (select-window window))
                (remove-hook 'post-command-hook postfun))))
      (add-hook 'post-command-hook postfun))))


(provide 'display-buffer-pivot-window-utility)

;; Local Variables:
;; checkdoc-allow-quoting-nil-and-t: t
;; End:

;;; display-buffer-pivot-window-utility.el ends here
