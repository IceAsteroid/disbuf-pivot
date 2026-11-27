;;; disbuf-pivot-window-utility.el --- Small snippets for window management  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/disbuf-pivot
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; The window predicates (displayable, eligible, and splittable), the
;; cannot-prompt context guards, the split primitives and options, the
;; dispatch prompt options and label faces, the window prompt that the
;; package's `display-buffer-alist' entry and the prefix commands use,
;; and the post-command selection that `display-buffer' uses for a `nil'
;; `post-command-select-window' entry.

;;; Code:

(require 'ace-window)
(require 'cl-lib)

(defun dp-window-utility-split-fair (&optional window)
  "Split WINDOW right or below according to its aspect ratio.
WINDOW defaults to the selected window.  On a graphic display compare
pixel body dimensions; on a text terminal treat each character cell as
twice as tall as it is wide.  When the preferred direction fails to
split, fall back to the other direction before re-signaling the primary
error.  Return the newly made window."
  (let* ((win (or window (selected-window)))
         (prefer-right
          (if (display-graphic-p (window-frame win))
              (> (window-body-width win t) (window-body-height win t))
            (> (window-body-width win) (* 2 (window-body-height win)))))
         (primary (if prefer-right #'split-window-right #'split-window-below))
         (fallback (if prefer-right #'split-window-below #'split-window-right)))
    (condition-case primary-err
        (funcall primary nil win)
      (error
       (condition-case nil
           (funcall fallback nil win)
         (error
          (signal (car primary-err) (cdr primary-err))))))))

(defcustom dp-window-keys '(?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9)
  "List of key characters used for window labels in the dispatch prompt.
Keys already taken by `disbuf-pivot-split-actions' are skipped and
duplicates are removed in order.  When the window count exceeds the
usable key count, labels switch to uniform fixed-width multi-key
strings."
  :type '(choice (const :tag "Digits 1-9" (?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9))
                 (const :tag "QWERTY home row" (?a ?s ?d ?f ?g ?h ?j ?k ?l))
                 (repeat :tag "Custom key list" character))
  :group 'disbuf-pivot)

(defcustom dp-split-actions
  '((?b split-window-below "Split below")
    (?r split-window-right "Split right")
    (?f dp-window-utility-split-fair "Split fair"))
  "Alist of split dispatch actions for the dispatch prompt.
Each element has the form `(KEY FUNCTION DESCRIPTION)', where KEY is a
character, FUNCTION splits the selected window and returns the newly
made window, and DESCRIPTION is shown in the dispatch action group."
  :type '(repeat (list (character :tag "Key")
                       (function :tag "Split function")
                       (string :tag "Description")))
  :group 'disbuf-pivot)

(defcustom dp-menu-min-column-width 20
  "Minimum column width in columns for dispatch prompt menu groups.
Controls how many dispatch prompt menu groups sit side by side (three,
two, or one stacked column) and wraps long lines inside each column.
When available frame width is below this value, the dispatch prompt
falls back to a compact echo-area prompt while keeping window labels."
  :type '(integer :match (lambda (_widget value)
                           (and (integerp value) (> value 0))))
  :group 'disbuf-pivot)

(defcustom dp-menu-min-height 5
  "Minimum height in lines for the dispatch prompt menu side window.
When the dispatch prompt menu is taller than available space and
available height is at least this value, the menu window is scrollable.
When available height is below this value, the dispatch prompt falls
back to a compact echo-area prompt while keeping window labels."
  :type '(integer :match (lambda (_widget value)
                           (and (integerp value) (> value 0))))
  :group 'disbuf-pivot)

(defface dp-eligible-label
  '((t :inherit (bold font-lock-keyword-face)))
  "Face for eligible window labels in the dispatch prompt."
  :group 'disbuf-pivot)

(defface dp-ineligible-label
  '((t :inherit shadow))
  "Face for ineligible window labels in the dispatch prompt."
  :group 'disbuf-pivot)

(defvar dp-window-utility--in-prompt nil
  "Non-nil while the package is prompting or performing guarded display.")

(defun dp-window-utility--resolve-buffer (buffer)
  "Return the buffer object designated by BUFFER, or `nil'."
  (cond ((bufferp buffer) buffer)
        ((stringp buffer) (get-buffer buffer))))

(defun dp-window-utility-displayable-p (window &optional buffer)
  "Return non-nil if WINDOW can directly display BUFFER.
WINDOW is displayable when it is live, is not a minibuffer window, is
not a side window, and is not dedicated to another buffer.  A non-side
window dedicated to BUFFER itself is displayable.  When BUFFER is `nil',
any dedicated window is undisplayable."
  (let ((buf (dp-window-utility--resolve-buffer buffer)))
    (and (window-live-p window)
         (not (window-minibuffer-p window))
         (not (window-parameter window 'window-side))
         (or (not (window-dedicated-p window))
             (and buf (eq buf (window-buffer window)))))))

(defun dp-window-utility-eligible-p (window buffer &optional excluded-window)
  "Return non-nil if WINDOW is eligible for direct display of BUFFER.
WINDOW must be displayable for BUFFER and not equal to EXCLUDED-WINDOW.
Only explicit user prefix intent (`disbuf-pivot-other-window-prefix')
passes EXCLUDED-WINDOW; caller intent never makes a displayable window
ineligible."
  (and (dp-window-utility-displayable-p window buffer)
       (not (and excluded-window (eq window excluded-window)))))

(defun dp-window-utility-ineligible-reason
    (window buffer &optional excluded-window)
  "Return why WINDOW is ineligible for BUFFER, or `nil' if eligible.
EXCLUDED-WINDOW is the window excluded by
`disbuf-pivot-other-window-prefix', if any."
  (let ((buf (dp-window-utility--resolve-buffer buffer)))
    (cond
     ((not (window-live-p window))
      "window is no longer live")
     ((window-minibuffer-p window)
      "minibuffer window")
     ((window-parameter window 'window-side)
      "side window")
     ((and (window-dedicated-p window)
           (not (and buf (eq buf (window-buffer window)))))
      (format "dedicated to %s" (buffer-name (window-buffer window))))
     ((and excluded-window (eq window excluded-window))
      "excluded by other-window-prefix"))))

(defun dp-window-utility-splittable-p (window)
  "Return non-nil if WINDOW is a splittable target for a split action.
WINDOW is splittable when it is live, is not a minibuffer window, is not
a side window, and its frame does not have a non-nil `unsplittable'
parameter.  A dedicated normal window is splittable."
  (and (window-live-p window)
       (not (window-minibuffer-p window))
       (not (window-parameter window 'window-side))
       (not (frame-parameter (window-frame window) 'unsplittable))))

(defun dp-window-utility-cannot-display-p (window &optional buffer)
  "Return non-nil if WINDOW cannot directly display BUFFER.
This is the negation of `disbuf-pivot-window-utility-displayable-p'."
  (not (dp-window-utility-displayable-p window buffer)))

(defun dp-window-utility--in-async-context-p ()
  "Return non-nil if running inside a timer or process callback."
  (or inhibit-quit
      (waiting-for-user-input-p)
      (catch 'dp-window-utility--async
        (mapbacktrace
         (lambda (evald func args _flags)
           (when (or (memq func '(timer-event-handler
                                  accept-process-output
                                  sit-for
                                  sleep-for
                                  delete-process))
                     (and evald
                          (consp args)
                          (processp (car args))
                          (let ((proc (car args)))
                            (or (eq func (process-filter proc))
                                (eq func (process-sentinel proc))))))
             (throw 'dp-window-utility--async t))))
        nil)))

(defun dp-window-utility-cannot-prompt-p ()
  "Return non-nil in a context where interactive prompting is impossible.
This covers batch (`noninteractive'), an active minibuffer, keyboard
macro execution (`executing-kbd-macro'), timers, process filters and
sentinels, and recursive display during an open prompt, tab or frame
creation, or consult preview."
  (or noninteractive
      (active-minibuffer-window)
      executing-kbd-macro
      dp-window-utility--in-prompt
      (bound-and-true-p dp-tab-bar--in-progress)
      (dp-window-utility--in-async-context-p)))

(defcustom dp-window-utility-split-maximum 4
  "The number of windows under which a split is preferred over asking.
When fewer windows than this can take a buffer's display, split a new
one with `display-buffer-pop-up-window'; at this number or more, ask
for a window with `ace-window' instead.
`disbuf-pivot-window-utility-split-p' makes the test."
  :group 'windows
  :type 'integer)

(defcustom dp-window-utility-split-maximum-exclude-side t
  "Non-nil to leave side windows out of the split count.
See `disbuf-pivot-window-utility-split-maximum'."
  :group 'windows
  :type 'boolean)

(defcustom dp-window-utility-split-maximum-exclude-dedicated t
  "Non-nil to leave dedicated windows out of the split count.
See `disbuf-pivot-window-utility-split-maximum'."
  :group 'windows
  :type 'boolean)

(defun dp-window-utility-split-p ()
  "Return non-nil when a split is preferred over asking for a window.
Count the windows `aw-window-list' offers, leaving out the side windows
and dedicated windows that
`disbuf-pivot-window-utility-split-maximum-exclude-side' and
`disbuf-pivot-window-utility-split-maximum-exclude-dedicated' exclude,
and compare the count with
`disbuf-pivot-window-utility-split-maximum'."
  (let ((count (cl-count-if
                (lambda (window)
                  (and (not (and dp-window-utility-split-maximum-exclude-side
                                 (window-parameter window 'window-side)))
                       (not (and dp-window-utility-split-maximum-exclude-dedicated
                                 (window-dedicated-p window)))))
                (aw-window-list))))
    (< count dp-window-utility-split-maximum)))

(defcustom dp-mode-line-help nil
  "Non-nil to show the dispatch hint in the mode line.
The dispatch hint is `Display buffer in window (? for actions)' or
`Choose another window (? for actions)'.  Nil hides only the
mode-line copy; the echo area still shows the hint.  This does not
affect `ace-window-display-mode' labels."
  :group 'windows
  :type 'boolean)

(defun dp-window-utility--dispatch-hint (first mode-line)
  "Return the window prompt's dispatch hint, or nil when `?' is unbound.
When FIRST is non-nil, use MODE-LINE; otherwise use `Choose another
window`.  Append ` (? for actions)' when `aw-dispatch-alist' binds `?'.
The hint is the one-line text shown in the echo area; the mode-line
copy is controlled by `disbuf-pivot-mode-line-help'."
  (when (assq ?? aw-dispatch-alist)
    (concat (if first mode-line "Choose another window")
            " (? for actions)")))

(defun dp-window-utility--aw-mode-line (first mode-line)
  "Return the mode-line copy of the dispatch hint, or nil.
When FIRST is non-nil, use MODE-LINE; otherwise use `Choose another
window`.  Append ` (? for actions)' when `aw-dispatch-alist' binds `?'.
Return the base string without the hint when `?' is unbound.
`disbuf-pivot-mode-line-help' controls whether a string is returned."
  (when dp-mode-line-help
    (or (dp-window-utility--dispatch-hint first mode-line)
        (if first mode-line "Choose another window"))))

(defun dp-window-utility--aw-show-hint (first mode-line)
  "Show the dispatch hint in the echo area when it exists.
FIRST and MODE-LINE are passed to
`disbuf-pivot-window-utility--dispatch-hint'."
  (let ((hint (dp-window-utility--dispatch-hint first mode-line)))
    (when hint
      (message "%s" hint))))

(defun dp-window-utility--aw-repeat-message (&optional hint)
  "Say that the chosen window cannot display the buffer.
Append HINT on a new line when non-nil."
  (message "%s%s"
           (concat "disbuf-pivot: the chosen window cannot display "
                   "the buffer; choose another")
           (if hint (concat "\n" hint) "")))

(defun dp-window-utility-choose-display-window
    (scope ignore-current &optional mode-line buffer)
  "Ask for a window with `aw-select' to display BUFFER in.
SCOPE and IGNORE-CURRENT are bound to `aw-scope' and
`aw-ignore-current' for the choice; MODE-LINE is passed to `aw-select'
and defaults to `Display buffer in window'; the mode line also offers
`? for actions' when `aw-dispatch-alist' binds it.  BUFFER is passed to
`disbuf-pivot-window-utility-cannot-display-p' when provided.

The echo area shows the dispatch hint before the choice.  Ask again
while the chosen window cannot display BUFFER, a window
`disbuf-pivot-window-utility-cannot-display-p' answers for; the echo
area says why.  Should the choice return the window it was told to
ignore -- `aw-select' has none other to offer -- choose nothing.

Return the chosen window, or `nil' when SCOPE is nil, in a cannot-prompt
context (`disbuf-pivot-window-utility-cannot-prompt-p'), when the choice
is cancelled, or when no window was chosen.  Cancelling the choice
\(`\\[keyboard-quit]') quits the command whose display it is."
  (when (and scope
             (not (dp-window-utility-cannot-prompt-p)))
    (let ((dp-window-utility--in-prompt t)
          (aw-scope scope)
          (aw-ignore-current ignore-current)
          (base (or mode-line "Display buffer in window"))
          (first t)
          done win)
      (while (and (not done)
                  (progn
                    (if first
                        (dp-window-utility--aw-show-hint first base)
                      (dp-window-utility--aw-repeat-message
                       (dp-window-utility--dispatch-hint nil base)))
                    (let ((mode-line
                           (dp-window-utility--aw-mode-line first base)))
                      (setq first nil)
                      (let ((aw-minibuffer-flag nil))
                        (setq win (aw-select mode-line)))))
                  (window-live-p win))
        (cond
         ;; `aw-select' returns the window it was told to ignore when it
         ;; has none other to offer: its branch for one window returns
         ;; `(or (car wnd-list) start-window)' whatever
         ;; `aw-ignore-current' says.  Stop asking and choose nothing.
         ((and aw-ignore-current (eq win (selected-window)))
          (setq done t
                win nil))
         ((dp-window-utility-cannot-display-p win buffer))
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
key is accepted; any other key returns nil.  `\\[keyboard-quit]'
quits."
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

(defun dp-window-utility-choose-tab-window (alist &optional buffer)
  "Ask for a window of the selected frame for ALIST and BUFFER.
With one window, `disbuf-pivot-window-utility-choose-sole-window' shows
the split keys and reads a key.  With more, `aw-select' shows the
labels; the echo area shows the dispatch hint and the mode line may copy
it.  Ask again while the chosen window cannot display BUFFER; the echo
area says why.  The `inhibit-same-window' entry of ALIST, and a selected
window that cannot display BUFFER, are excluded.  Return the window, or
`nil' in a cannot-prompt context or when no window is chosen."
  (unless (dp-window-utility-cannot-prompt-p)
    (let ((dp-window-utility--in-prompt t)
          (windows (window-list nil 'no-minibuf))
          (ignore-current
           (or (cdr (assq 'inhibit-same-window alist))
               (dp-window-utility-cannot-display-p (selected-window) buffer))))
      (if (null (cdr windows))
          (dp-window-utility-choose-sole-window (car windows) ignore-current)
        (let ((aw-scope 'frame)
              (aw-ignore-current ignore-current)
              (aw-dispatch-when-more-than 0)
              (first t)
              done win)
          (while (and (not done)
                      (progn
                        (if first
                            (dp-window-utility--aw-show-hint
                             first "Display buffer in window")
                          (dp-window-utility--aw-repeat-message
                           (dp-window-utility--dispatch-hint
                            nil "Display buffer in window")))
                        (let ((mode-line
                               (dp-window-utility--aw-mode-line
                                first "Display buffer in window")))
                          (setq first nil)
                          (let ((aw-minibuffer-flag nil))
                            (setq win (aw-select mode-line)))))
                      (window-live-p win))
            (cond
             ((dp-window-utility-cannot-display-p win buffer))
             ((and aw-ignore-current (eq win (selected-window))))
             (t (setq done t))))
          win)))))

(provide 'dp-window-utility)

;; Local Variables:
;; checkdoc-allow-quoting-nil-and-t: t
;; read-symbol-shorthands: (("dp-" . "disbuf-pivot-"))
;; End:

;;; disbuf-pivot-window-utility.el ends here
