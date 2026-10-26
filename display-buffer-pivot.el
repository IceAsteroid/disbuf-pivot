;;; display-buffer-pivot.el --- Choose the window of a buffer the selected window cannot display  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/display-buffer-pivot
;; Version: 0.0.0
;; Package-Requires: ((emacs "31.1") (ace-window "0"))
;; Keywords: convenience, windows
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; When the selected window cannot display a buffer -- it is dedicated
;; or a side window -- the window the buffer goes to is
;; Emacs's choice, made by its default action functions, so the buffer
;; lands where the user does not expect it.  `display-buffer-pivot-action-mode'
;; replaces that with one rule and one choice: a buffer is displayed in a
;; window that already displays it, else in the selected window, and a
;; buffer the selected window cannot display is displayed in a new window
;; when `display-buffer-pivot-window-utility-split-p' says a split is preferred, else in a window
;; the user chooses with `ace-window' -- choosing again while the chosen
;; window is one that cannot display it either.  A call that asks for a
;; tab or a frame is asked which one, or a new one, and the window inside
;; it is chosen with `aw-select' after a window that already displays the
;; buffer is used.
;;
;; The mode conses one `display-buffer-alist' entry at the front of the
;; list, matched by every buffer an earlier entry does not take.  Priority
;; is list order, and a package conses its entry at the front when its
;; mode is enabled, so enable a popup manager's mode after this one when
;; its rule is to take precedence for its buffers.  A request whose alist
;; names a place for the buffer -- a window, a direction, a side, a slot,
;; a tab or a frame -- is left to the caller's own action functions.

(require 'cl-lib)
(require 'ace-window)
(require 'tab-bar)
(require 'display-buffer-pivot-window-utility)
(require 'display-buffer-pivot-tab-bar)

;;; Code:

(defgroup display-buffer-pivot-action nil
  "Choose the window of a buffer the selected window cannot display."
  :group 'windows
  :prefix "display-buffer-pivot-action-")

(defcustom display-buffer-pivot-action-select t
  "Whether the action selects the window you chose.

`t' selects the chosen window after displaying the buffer, so the choice
always lands point where you pointed.

`auto' selects nothing: the caller decides -- `pop-to-buffer' selects
the window it displays, and a caller that does not select leaves the
selection alone.

`nil' selects nothing either, and undoes a caller that selects: at the
end of the command the window that was selected when the action ran is
selected again, the way `display-buffer' treats a `nil'
`post-command-select-window' entry."
  :type '(choice (const :tag "Always select" t)
                 (const :tag "Let the caller decide" auto)
                 (const :tag "Never select" nil))
  :group 'display-buffer-pivot-action)

(defcustom display-buffer-pivot-action-functions
  '(display-buffer-reuse-window
    display-buffer-same-window
    display-buffer-pivot-action-split-or-ask)
  "The action functions the mode's entry tries, in order.
Each is called with the buffer and the action alist, and the first one
that returns a window decides the display.  The default shows a buffer
in a window that already displays it, else in the selected window, and
otherwise splits a new window when `display-buffer-pivot-window-utility-split-p' says a split is
preferred, or asks for a window with `ace-window'.

An action function can be added, dropped or reordered here: putting
`display-buffer-same-window' first gives a buffer that another window
already displays a second window, and dropping
`display-buffer-pivot-action-split-or-ask' removes the split and the
prompt.  A request whose alist names a place for the buffer -- a
window, a direction, a side, a slot, or a child frame -- is left to the
caller's own action functions before any function here is tried; a call
that asks for a tab or a frame is asked which one first, and the window
inside it is chosen with `aw-select'."
  :type '(choice (function :tag "One action function")
                 (repeat :tag "Action functions" function))
  :group 'display-buffer-pivot-action)

(defvar display-buffer-pivot-action--action nil
  "The ACTION argument of the `display-buffer' call being decided.
The condition of the mode's entry records it, because `buffer-match-p'
passes the ACTION to the condition and the action functions receive only
the merged alist.")

(defun display-buffer-pivot-action-control-p (_buffer action)
  "Match every buffer an earlier `display-buffer-alist' entry does not take.
This is the condition of the entry `display-buffer-pivot-action-mode'
installs, so the mode's function is tried after column-popup's entry and
before the caller's ACTION argument, the special action,
`display-buffer-base-action' and the fallback action.  Record ACTION for
`display-buffer-pivot-action--target'."
  (setq display-buffer-pivot-action--action action)
  t)

(defun display-buffer-pivot-action--functions (action)
  "Return the action functions ACTION names, as a list."
  (let ((functions (car-safe action)))
    (cond ((functionp functions) (list functions))
          ((listp functions) functions))))

(defun display-buffer-pivot-action--target (alist)
  "Return `tab', `frame' or nil for the display ALIST and its ACTION.
A tab is asked for through `tab-name' or `tab-group', or through
`display-buffer-in-tab' or `display-buffer-in-new-tab' in the ACTION.  A
frame is asked for through `pop-up-frames', or through
`display-buffer-pop-up-frame' or `display-buffer-use-some-frame' in the
ACTION.  A child frame named by `parent-frame' is left to the caller."
  (let ((functions (display-buffer-pivot-action--functions
                    display-buffer-pivot-action--action)))
    (cond
     ((or (assq 'tab-name alist)
          (assq 'tab-group alist)
          (memq 'display-buffer-in-tab functions)
          (memq 'display-buffer-in-new-tab functions))
      'tab)
     ((or (assq 'pop-up-frames alist)
          (memq 'display-buffer-pop-up-frame functions)
          (memq 'display-buffer-use-some-frame functions))
      'frame))))

(defun display-buffer-pivot-action--run (buffer alist)
  "Display BUFFER by the functions `display-buffer-pivot-action-functions' lists.
ALIST is passed to each function.  Return the first window they display,
or nil."
  (let ((functions display-buffer-pivot-action-functions))
    (unless (listp functions)
      (setq functions (list functions)))
    (cl-some (lambda (function) (funcall function buffer alist))
             functions)))

(defun display-buffer-pivot-action--read-tab-name (buffer alist)
  "Read the name of a tab for BUFFER, using ALIST's `tab-name' first.
A `tab-name' function is called with BUFFER and ALIST.  Otherwise read
a name with `display-buffer-pivot-tab-bar-read-tab-name', where an
empty name is returned as such."
  (let ((name (alist-get 'tab-name alist)))
    (cond ((functionp name) (funcall name buffer alist))
          (name name)
          (t (display-buffer-pivot-tab-bar-read-tab-name
              "Display buffer in tab (empty for a new tab): " "")))))

(defun display-buffer-pivot-action--select-tab (buffer alist name)
  "Select the tab NAME for BUFFER, or make a new tab with that name.
An existing name selects its tab and returns `reuse'; a new or empty
name makes a tab and returns `tab'.  The `tab-group' entry of ALIST
names the group of a new tab; a function there is called with BUFFER and
ALIST."
  (let* ((candidates (display-buffer-pivot-tab-bar--get-candidates))
         (match (and name (assoc-string name candidates)))
         (index (nth 1 match))
         (target-name (if match (nth 2 match) name)))
    (if index
        (progn
          (tab-bar-select-tab index)
          'reuse)
      (tab-bar-new-tab)
      (when (bound-and-true-p display-buffer-pivot-tab-bar-sanitize-new-tab)
        (set-window-prev-buffers (selected-window) nil)
        (set-window-next-buffers (selected-window) nil))
      (unless (or (null name) (string-empty-p name))
        (tab-bar-rename-tab target-name))
      (let ((group (alist-get 'tab-group alist)))
        (when (functionp group)
          (setq group (funcall group buffer alist)))
        (when group
          (tab-bar-change-tab-group group)))
      'tab)))

(defun display-buffer-pivot-action--split-actions ()
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

(defun display-buffer-pivot-action--split-help (actions)
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

(defun display-buffer-pivot-action--choose-sole-window (window)
  "Return WINDOW, or the window a split key makes from it.
Read one key.  A key bound to a split action in `aw-dispatch-alist'
splits WINDOW and the new window is returned; any other key returns
WINDOW.  The split keys and their descriptions are shown first.  C-g
quits."
  (let* ((split-actions (display-buffer-pivot-action--split-actions)))
    (message "%s"
             (if split-actions
                 (format "%s\nAny other key uses this window"
                         (display-buffer-pivot-action--split-help split-actions))
               "Any other key uses this window"))
    (let* ((key (read-char))
           (action (assq key split-actions)))
      (if action
          (let ((new (funcall (nth 1 action) window)))
            (if (window-live-p new) new window))
        window))))

(defun display-buffer-pivot-action--choose-tab-window ()
  "Ask for a window of the selected frame.
With one window, `display-buffer-pivot-action--choose-sole-window' shows
the split keys and reads a key.  With more, `aw-select' shows the labels
and the user's `aw-dispatch-alist' actions.  Ask again while the chosen
window cannot display a buffer.  Return the window, or nil."
  (let ((windows (window-list nil 'no-minibuf)))
    (if (null (cdr windows))
        (display-buffer-pivot-action--choose-sole-window (car windows))
      (let ((aw-scope 'frame)
            (aw-ignore-current nil)
            (aw-dispatch-when-more-than 0)
            done win)
        (while (and (not done)
                    (setq win (aw-select "Display buffer in window"))
                    (window-live-p win))
          (cond
           ((display-buffer-pivot-window-utility-cannot-display-p win))
           (t (setq done t))))
        win))))

(defun display-buffer-pivot-action--display-in-tab (buffer alist)
  "Display BUFFER in the selected tab, reusing a window or asking.
A window of the selected frame that already displays BUFFER is used
first.  Otherwise ask with `display-buffer-pivot-action--choose-tab-window'
and display BUFFER in the chosen or split window.  ALIST is passed to
`window--display-buffer'.  Return the window and `reuse' as a cons, or
nil when no window was chosen."
  (if-let* ((window (get-buffer-window buffer (selected-frame))))
      (progn
        (window--display-buffer buffer window 'reuse alist)
        (cons window 'reuse))
    (when-let* ((window (display-buffer-pivot-action--choose-tab-window)))
      (window--display-buffer buffer window 'reuse alist)
      (cons window 'reuse))))

(defun display-buffer-pivot-action-tab (buffer alist)
  "Display BUFFER in a tab, asking which and in which window.
When `reusable-frames' is non-nil, use `tab-bar-get-buffer-tab' first,
as `display-buffer-in-tab' does, and select the tab that already
displays BUFFER.  Otherwise read a name with
`display-buffer-pivot-action--read-tab-name' and select or make that tab.
  In the tab, reuse a window that already displays BUFFER; if there is
none, ask with `aw-select', where the split dispatch keys split the
chosen window.  ALIST is the action alist of the display.  Return the
window and the tab's type as a cons, `reuse' for an existing tab and
`tab' for a new one, or nil in batch or while the minibuffer is active."
  (when (and (not noninteractive)
             (not (active-minibuffer-window)))
    (let ((reusable (and (alist-get 'reusable-frames alist)
                         (tab-bar-get-buffer-tab
                          buffer
                          (alist-get 'reusable-frames alist)
                          (alist-get 'ignore-current-tab alist)))))
      (if reusable
          (progn
            (let ((frame (alist-get 'frame reusable))
                  (index (alist-get 'index reusable)))
              (when frame
                (select-frame-set-input-focus frame))
              (when index
                (tab-bar-select-tab (1+ index))))
            (display-buffer-pivot-action--display-in-tab buffer alist))
        (let* ((name (display-buffer-pivot-action--read-tab-name buffer alist))
               (type (display-buffer-pivot-action--select-tab buffer alist name))
               (result (display-buffer-pivot-action--display-in-tab buffer alist)))
          (when result
            (cons (car result) type)))))))

(defun display-buffer-pivot-action--frames (alist)
  "Return the live visible frames the frame prompt can offer.
A `frame-predicate' entry in ALIST filters them, as it does for
`display-buffer-use-some-frame'."
  (let ((frames
         (cl-remove-if-not
          (lambda (frame)
            (and (frame-live-p frame)
                 (frame-visible-p frame)
                 (not (eq (frame-parameter frame 'minibuffer) 'only))))
          (frame-list)))
        (predicate (alist-get 'frame-predicate alist)))
    (if (functionp predicate)
        (cl-remove-if-not predicate frames)
      frames)))

(defun display-buffer-pivot-action--frame (buffer alist)
  "Display BUFFER in a frame, asking which frame and which window.
Read a frame title; an empty title makes a new frame through
`display-buffer-pop-up-frame', which keeps the `pop-up-frame-parameters'
of ALIST.  A title that names a frame selects it, giving focus unless
`inhibit-switch-frame'; when that frame has more than one tab, read a
tab name and select or make that tab.  Then reuse a window of the tab
that already displays BUFFER, or ask with `aw-select', where the split
dispatch keys split the chosen window.  Return the window, or nil in
batch or while the minibuffer is active."
  (when (and (not noninteractive)
             (not (active-minibuffer-window)))
    (let* ((frames (display-buffer-pivot-action--frames alist))
           (name (completing-read
                  "Frame (empty for a new frame): "
                  (delq nil (mapcar (lambda (frame)
                                      (frame-parameter frame 'name))
                                    frames))
                  nil nil))
           (frame (and (not (string-empty-p name))
                       (cl-find name frames
                                :key (lambda (frame)
                                       (frame-parameter frame 'name))
                                :test #'equal))))
      (if frame
          (progn
            (if (alist-get 'inhibit-switch-frame alist)
                (select-frame frame)
              (select-frame-set-input-focus frame))
            (when (> (length (tab-bar-tabs)) 1)
              (let ((tab-name (display-buffer-pivot-action--read-tab-name
                               buffer alist)))
                (display-buffer-pivot-action--select-tab buffer alist tab-name)))
            (let ((result (display-buffer-pivot-action--display-in-tab
                           buffer alist)))
              (when result
                (car result))))
        (display-buffer-pop-up-frame buffer alist)))))

(defun display-buffer-pivot-action--placed-p (alist)
  "Return non-nil if ALIST names a place for the buffer.
A window, a direction, a side, a slot, or a child frame named in ALIST is
a deliberate placement, left to the caller's own action functions.  A tab
or a frame that is not a child frame is asked about instead."
  (cl-some (lambda (key) (assq key alist))
           '(window direction side slot
             parent-frame child-frame-parameters)))

(defun display-buffer-pivot-action-choose-window (buffer alist)
  "Display BUFFER in a window chosen with `ace-window'.
`display-buffer-pivot-window-utility-choose-display-window' asks for the window: it asks again while the
chosen window cannot display BUFFER, and chooses nothing when no window
can answer.  The chosen window displays BUFFER through
`window--display-buffer' with ALIST, so the caller's entries -- a
`body-function' among them -- still take effect.  What
`display-buffer-pivot-action-select' does with the selected window is its
own choice: `t' selects the chosen window, `auto' selects nothing, and
`nil' selects nothing now and selects the answering window again at the
end of the command."
  (let* ((aw-scope (cl-case (cdr (assq 'reusable-frames alist))
                     ((nil) 'frame)
                     (visible 'visible)
                     ((0 t) 'global)))
         (aw-ignore-current (or (cdr (assq 'inhibit-same-window alist))
                                (display-buffer-pivot-window-utility-cannot-display-p (selected-window)))))
    (when-let* ((win (display-buffer-pivot-window-utility-choose-display-window aw-scope aw-ignore-current)))
      (let ((answering (selected-window)))
        (window--display-buffer buffer win 'reuse alist)
        (pcase display-buffer-pivot-action-select
          ('t (select-window win))
          ('nil (display-buffer-pivot-window-utility-select-window-post-command answering))))
      win)))

(defun display-buffer-pivot-action-split-or-ask (buffer alist)
  "Display BUFFER in a new window when a split is preferred, else ask.
`display-buffer-pivot-window-utility-split-p' decides through `display-buffer-pivot-window-utility-split-maximum' and its
two exclusion options.  When it says a split is preferred, try
`display-buffer-pop-up-window'; when that fails, and when the count is
not under the maximum, ask with `display-buffer-pivot-action-choose-window'.
BUFFER and ALIST are passed to whichever of the two displays it."
  (or (and (display-buffer-pivot-window-utility-split-p)
           (display-buffer-pop-up-window buffer alist))
      (display-buffer-pivot-action-choose-window buffer alist)))

(defun display-buffer-pivot-action--display (buffer alist)
  "Display BUFFER by the mode's rule.
When the call asks for a tab or a frame, ask which one, or a new one, and
display BUFFER there by the action functions.  Otherwise, unless ALIST
names a place for the buffer, call the functions of
`display-buffer-pivot-action-functions' in order and return the first window
they display."
  (pcase (display-buffer-pivot-action--target alist)
    ('tab (car-safe (display-buffer-pivot-action-tab buffer alist)))
    ('frame (display-buffer-pivot-action--frame buffer alist))
    (_
     (unless (display-buffer-pivot-action--placed-p alist)
       (display-buffer-pivot-action--run buffer alist)))))

(defun display-buffer-pivot-action--rule ()
  "Return the entry `display-buffer-pivot-action-mode' installs."
  (cons 'display-buffer-pivot-action-control-p
        '(display-buffer-pivot-action--display)))

(defun display-buffer-pivot-action--install ()
  "Cons the mode's entry at the front of `display-buffer-alist'.
An entry `display-buffer-pivot-action-control-p' already present is
replaced, so enabling an enabled mode leaves one entry."
  (setq display-buffer-alist
        (cons (display-buffer-pivot-action--rule)
              (cl-remove 'display-buffer-pivot-action-control-p
                         display-buffer-alist :key 'car))))

(defun display-buffer-pivot-action--uninstall ()
  "Remove the mode's entry, and nothing else."
  (setq display-buffer-alist
        (cl-remove 'display-buffer-pivot-action-control-p
                   display-buffer-alist :key 'car)))

;;;###autoload
(define-minor-mode display-buffer-pivot-action-mode
  "Choose the window of a buffer the selected window cannot display.
When enabled, cons a `display-buffer-alist' entry at the front of the
list, matching every buffer an earlier entry does not take.  Priority is
list order: a popup manager's rule takes precedence for its buffers when
that manager's mode is enabled after this one, since its entry is then
consed above.  The entry's function displays a buffer in a window that
already displays it or in the selected window, then splits a new window
when `display-buffer-pivot-window-utility-split-p' says a split is preferred, and otherwise asks
for a window with `ace-window', by the action functions
`display-buffer-pivot-action-functions' lists in order.  A call that asks
for a tab or a frame -- through `tab-name', `tab-group',
`pop-up-frames', or a tab or frame action function in its ACTION -- is
asked which one, or a new one, then asked for the window inside it with
`aw-select', where the split dispatch keys split the chosen window.  A
request whose alist names a window, a direction, a side, a slot, or a
child frame is left to the caller's own action functions, and
`display-buffer-overriding-action' is consulted before the entry.
When disabled, remove that entry."
  :global t
  :group 'display-buffer-pivot-action
  (if display-buffer-pivot-action-mode
      (display-buffer-pivot-action--install)
    (display-buffer-pivot-action--uninstall)))

(provide 'display-buffer-pivot)

;; Local Variables:
;; checkdoc-allow-quoting-nil-and-t: t
;; End:

;;; display-buffer-pivot-action.el ends here
