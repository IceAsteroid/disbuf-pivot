;;; disbuf-pivot-window-utility.el --- Small snippets for window management  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/display-buffer-pivot
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; The window test and the split options; the window prompt that the
;; display action and the prefix commands use; and the post-command
;; selection that `display-buffer' uses for a `nil'
;; `post-command-select-window' entry.

;;; Code:

(require 'ace-window)
(require 'cl-lib)

(defun dp-window-utility-cannot-display-p (window)
  "Return non-nil if WINDOW does not take another buffer's display.
That is a window dedicated to its buffer or a side window."
  (or (window-dedicated-p window)
      (window-parameter window 'window-side)))

(defcustom dp-window-utility-split-maximum 4
  "The number of windows under which a split is preferred over asking.
When fewer windows than this can take a buffer's display, split a new
one with `display-buffer-pop-up-window'; at this number or more, ask
for a window with `ace-window' instead.  `disbuf-pivot-window-utility-split-p' makes the
test."
  :group 'windows
  :type 'integer)

(defcustom dp-window-utility-split-maximum-exclude-side t
  "Non-nil to leave side windows out of `disbuf-pivot-window-utility-split-maximum'."
  :group 'windows
  :type 'boolean)

(defcustom dp-window-utility-split-maximum-exclude-dedicated t
  "Non-nil to leave dedicated windows out of `disbuf-pivot-window-utility-split-maximum'."
  :group 'windows
  :type 'boolean)

(defun dp-window-utility-split-p ()
  "Return non-nil when a split is preferred over asking for a window.
Count the windows `aw-window-list' offers, leaving out the side windows
and dedicated windows that `disbuf-pivot-window-utility-split-maximum-exclude-side' and
`disbuf-pivot-window-utility-split-maximum-exclude-dedicated' exclude, and compare the
count with `disbuf-pivot-window-utility-split-maximum'."
  (let ((count (cl-count-if
                (lambda (window)
                  (and (not (and dp-window-utility-split-maximum-exclude-side
                                 (window-parameter window 'window-side)))
                       (not (and dp-window-utility-split-maximum-exclude-dedicated
                                 (window-dedicated-p window)))))
                (aw-window-list))))
    (< count dp-window-utility-split-maximum)))

(defun dp-window-utility-choose-display-window (scope ignore-current &optional mode-line)
  "Ask for a window with `aw-select' to display a buffer in.
SCOPE and IGNORE-CURRENT are bound to `aw-scope' and
`aw-ignore-current' for the choice; MODE-LINE is passed to `aw-select'
and defaults to \"Display buffer in window\".

Ask again while the chosen window cannot display the buffer, a window
`disbuf-pivot-window-utility-cannot-display-p' answers for.  Should the choice return the
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
         ((dp-window-utility-cannot-display-p win))
         (t (setq done t))))
      win)))

(defun dp-window-utility-select-window-post-command (window)
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

(defun dp-window-utility--split-actions ()
  "Return the `aw-dispatch-alist' entries that split a window.
The keys and descriptions are the user's, so a rebound split key is
shown as it is bound.  Actions that delete, swap or otherwise change
another window are left out: this prompt only chooses where to display
a buffer."
  (cl-remove-if-not
   (lambda (action)
     (memq (nth 1 action)
           '(aw-split-window-vert aw-split-window-horz aw-split-window-fair)))
   aw-dispatch-alist))

(defun dp-window-utility--split-help (actions)
  "Return ACTIONS with their keys and descriptions, one per line.
The format is the one `aw-show-dispatch-help' uses; that command ends by
calling `ace-window', so its text is made here from the same alist."
  (mapconcat
   (lambda (action)
     (cl-destructuring-bind (key function &optional description) action
       (format "%s: %s"
               (propertize (char-to-string key) 'face 'aw-key-face)
               (or description function))))
   actions
   "\n"))

(defun dp-window-utility-choose-sole-window (window &optional ignore-current)
  "Return WINDOW, or the window a split key makes from it.
Read one key.  A key bound to a split action in `aw-dispatch-alist'
splits WINDOW and the new window is returned; any other key returns
WINDOW.  The split keys and their descriptions are shown first.  When
IGNORE-CURRENT is non-nil and WINDOW is the selected window, only a split
key is accepted; any other key returns nil.  C-g quits."
  (let* ((split-actions (dp-window-utility--split-actions))
         (ignore (and ignore-current (eq window (selected-window)))))
    (message "%s"
             (if split-actions
                 (format "%s\n%s"
                         (dp-window-utility--split-help split-actions)
                         (if ignore
                             "Any other key cancels"
                           "Any other key uses this window"))
               (if ignore
                   "Any other key cancels"
                 "Any other key uses this window")))
    (let* ((key (read-char))
           (action (assq key split-actions)))
      (if action
          (let ((new (funcall (nth 1 action) window)))
            (if (window-live-p new) new window))
        (unless ignore
          window)))))

(defun dp-window-utility-choose-tab-window (alist)
  "Ask for a window of the selected frame for ALIST.
With one window, `disbuf-pivot-window-utility-choose-sole-window' shows the
split keys and reads a key.  With more, `aw-select' shows the labels and
the user's `aw-dispatch-alist' actions.  Ask again while the chosen window
cannot display a buffer.  The `inhibit-same-window' entry of ALIST, and a
selected window that cannot display a buffer, are excluded.  Return the
window, or nil."
  (let ((windows (window-list nil 'no-minibuf))
        (ignore-current
         (or (cdr (assq 'inhibit-same-window alist))
             (dp-window-utility-cannot-display-p (selected-window)))))
    (if (null (cdr windows))
        (dp-window-utility-choose-sole-window (car windows) ignore-current)
      (let ((aw-scope 'frame)
            (aw-ignore-current ignore-current)
            (aw-dispatch-when-more-than 0)
            done win)
        (while (and (not done)
                    (setq win (aw-select "Display buffer in window"))
                    (window-live-p win))
          (cond
           ((dp-window-utility-cannot-display-p win))
           ((and aw-ignore-current (eq win (selected-window))))
           (t (setq done t))))
        win))))

(provide 'dp-window-utility)

;; Local Variables:
;; checkdoc-allow-quoting-nil-and-t: t
;; read-symbol-shorthands: (("dp-" . "disbuf-pivot-"))
;; End:

;;; disbuf-pivot-window-utility.el ends here
