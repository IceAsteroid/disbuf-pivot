;;; disbuf-pivot.el --- Choose where to display a buffer the selected window cannot display  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/display-buffer-pivot
;; Version: 0.0.0
;; Package-Requires: ((emacs "31.1") (ace-window "0"))
;; Keywords: convenience, windows
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; The package is `disbuf-pivot'; `disbuf' is the short form of
;; `display-buffer', and the pivot is the display target: a window, a
;; tab or a frame.
;;
;; When the selected window cannot display a buffer -- it is dedicated
;; or a side window -- the window the buffer goes to is
;; Emacs's choice, made by its default action functions, so the buffer
;; lands where the user does not expect it.  `disbuf-pivot-action-mode'
;; replaces that with one rule and one choice: a buffer is displayed in a
;; window that already displays it, else in the selected window, and a
;; buffer the selected window cannot display is displayed in a new window
;; when `disbuf-pivot-window-utility-split-p' says a split is preferred, else in a window
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
(require 'subr-x)
(require 'ace-window)
(require 'tab-bar)
(require 'dp-window-utility)
(require 'dp-tab-bar)

;;; Code:

(defgroup dp-action nil
  "Choose where to display a buffer the selected window cannot display."
  :group 'windows
  :prefix "disbuf-pivot-action-")

(defcustom dp-action-select t
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
  :group 'dp-action)

(defcustom dp-action-functions
  '(display-buffer-reuse-window
    display-buffer-same-window
    dp-action-split-or-ask)
  "The action functions the mode's entry tries, in order.
Each is called with the buffer and the action alist, and the first one
that returns a window decides the display.  The default shows a buffer
in a window that already displays it, else in the selected window, and
otherwise splits a new window when `disbuf-pivot-window-utility-split-p' says a split is
preferred, or asks for a window with `ace-window'.

An action function can be added, dropped or reordered here: putting
`display-buffer-same-window' first gives a buffer that another window
already displays a second window, and dropping
`disbuf-pivot-action-split-or-ask' removes the split and the
prompt.  A request whose alist names a place for the buffer -- a
window, a direction, a side, a slot, or a child frame -- is left to the
caller's own action functions before any function here is tried; a call
that asks for a tab or a frame is asked which one first, and the window
inside it is chosen with `aw-select'."
  :type '(choice (function :tag "One action function")
                 (repeat :tag "Action functions" function))
  :group 'dp-action)

(defvar dp-action--action nil
  "The ACTION argument of the `display-buffer' call being decided.
The condition of the mode's entry records it, because `buffer-match-p'
passes the ACTION to the condition and the action functions receive only
the merged alist.")

(defun dp-action-control-p (_buffer action)
  "Match every buffer an earlier `display-buffer-alist' entry does not take.
This is the condition of the entry `disbuf-pivot-action-mode'
installs, so the mode's function is tried after column-popup's entry and
before the caller's ACTION argument, the special action,
`display-buffer-base-action' and the fallback action.  Record ACTION for
`disbuf-pivot-action--target'."
  (setq dp-action--action action)
  t)

(defun dp-action--functions (action)
  "Return the action functions ACTION names, as a list."
  (let ((functions (car-safe action)))
    (cond ((functionp functions) (list functions))
          ((listp functions) functions))))

(defun dp-action--target (alist)
  "Return `tab', `frame' or nil for the display ALIST and its ACTION.
A tab is asked for through `tab-name' or `tab-group', or through
`display-buffer-in-tab' or `display-buffer-in-new-tab' in the ACTION.  A
frame is asked for through a non-nil `pop-up-frames', or through
`display-buffer-pop-up-frame' or `display-buffer-use-some-frame' in the
ACTION.  A child frame named by `parent-frame' is left to the caller."
  (let ((functions (dp-action--functions
                    dp-action--action)))
    (cond
     ((or (assq 'tab-name alist)
          (assq 'tab-group alist)
          (memq 'display-buffer-in-tab functions)
          (memq 'display-buffer-in-new-tab functions))
      'tab)
     ((or (alist-get 'pop-up-frames alist)
          (memq 'display-buffer-pop-up-frame functions)
          (memq 'display-buffer-use-some-frame functions))
      'frame))))

(defun dp-action--run (buffer alist)
  "Display BUFFER by the functions `disbuf-pivot-action-functions' lists.
ALIST is passed to each function.  Return the first window they display,
or nil."
  (let ((functions dp-action-functions))
    (unless (listp functions)
      (setq functions (list functions)))
    (cl-some (lambda (function) (funcall function buffer alist))
             functions)))

(defun dp-action--read-tab-name (buffer alist)
  "Read the name of a tab for BUFFER, using ALIST's `tab-name' first.
A `tab-name' function is called with BUFFER and ALIST.  Otherwise read
a name with `disbuf-pivot-tab-bar-read-tab-name', where an
empty name is returned as such."
  (let ((name (alist-get 'tab-name alist)))
    (cond ((functionp name) (funcall name buffer alist))
          (name name)
          (t (dp-tab-bar-read-tab-name
              "Display buffer in tab (empty for a new tab): " "")))))

(defun dp-action--display-in-tab (buffer alist)
  "Display BUFFER in the selected tab, reusing a window or asking.
A window of the selected frame that already displays BUFFER is used
first, unless ALIST's `inhibit-same-window' names the selected window.
Otherwise ask with `disbuf-pivot-window-utility-choose-tab-window' and display
BUFFER in the chosen or split window.  ALIST is passed to
`window--display-buffer'.  Return the window and `reuse' as a cons, or
nil when no window was chosen."
  (let ((window (get-buffer-window buffer (selected-frame)))
        (inhibit-same (alist-get 'inhibit-same-window alist)))
    (if (and window
             (not (and inhibit-same (eq window (selected-window)))))
        (progn
          (window--display-buffer buffer window 'reuse alist)
          (cons window 'reuse))
      (when-let* ((window (dp-window-utility-choose-tab-window alist)))
        (window--display-buffer buffer window 'reuse alist)
        (cons window 'reuse)))))

(defun dp-action-tab (buffer alist)
  "Display BUFFER in a tab, asking which and in which window.
When `reusable-frames' is non-nil, use `tab-bar-get-buffer-tab' first,
as `display-buffer-in-tab' does, and select the tab that already
displays BUFFER.  Otherwise read a name with
`disbuf-pivot-action--read-tab-name' and select or make that tab.
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
            (dp-action--display-in-tab buffer alist))
        (let* ((name (dp-action--read-tab-name buffer alist))
               (type (dp-tab-bar-select-tab buffer alist name))
               (result (dp-action--display-in-tab buffer alist)))
          (when result
            (cons (car result) type)))))))

(defun dp-action--frames (alist)
  "Return the live visible frames the frame prompt can offer.
A `frame-predicate' entry in ALIST filters them, as it does for
`display-buffer-use-some-frame'.  A child frame is not offered: it is a
popup, not a frame the user chooses for a buffer."
  (let ((frames
         (cl-remove-if-not
          (lambda (frame)
            (and (frame-live-p frame)
                 (frame-visible-p frame)
                 (not (frame-parent frame))
                 (not (eq (frame-parameter frame 'minibuffer) 'only))))
          (frame-list)))
        (predicate (alist-get 'frame-predicate alist)))
    (if (functionp predicate)
        (cl-remove-if-not predicate frames)
      frames)))

(defun dp-action--frame-candidates (frames)
  "Return (NAME . FRAME) for FRAMES, disambiguating repeated names.
A frame without a name is `frame'; a repeated name gets `<N>' appended,
as the tab reader does for repeated tab names."
  (let ((counts (make-hash-table :test 'equal))
        (result nil))
    (dolist (frame frames)
      (let* ((raw (or (frame-parameter frame 'name) "frame"))
             (count (gethash raw counts 0))
             (name (if (= count 0) raw (format "%s<%d>" raw (1+ count)))))
        (puthash raw (1+ count) counts)
        (push (cons name frame) result)))
    (nreverse result)))

(defun dp-action--frame (buffer alist)
  "Display BUFFER in a frame, asking which frame and which window.
Read a frame name; an empty name makes a new frame through
`display-buffer-pop-up-frame', which keeps the `pop-up-frame-parameters'
of ALIST.  A name that names a frame selects it, giving focus unless
`inhibit-switch-frame'; an unknown non-empty name asks again.  When that
frame has more than one tab, read a tab name and select or make that tab.
Then reuse a window of the tab that already displays BUFFER, or ask with
`aw-select', where the split dispatch keys split the chosen window.
Return the window, or nil in batch or while the minibuffer is active."
  (when (and (not noninteractive)
             (not (active-minibuffer-window)))
    (let* ((frames (dp-action--frames alist))
           (candidates (dp-action--frame-candidates frames))
           (names (mapcar #'car candidates))
           (name (completing-read
                  "Frame (empty for a new frame): " names nil nil))
           (frame (cdr (assoc-string name candidates))))
      (while (and (not (string-empty-p name)) (not frame))
        (setq name (completing-read
                    "Frame name not found; try again (empty for a new frame): "
                    names nil nil)
              frame (cdr (assoc-string name candidates))))
      (if frame
          (progn
            (if (alist-get 'inhibit-switch-frame alist)
                (select-frame frame)
              (select-frame-set-input-focus frame))
            (when (> (length (tab-bar-tabs)) 1)
              (let ((tab-name (dp-action--read-tab-name
                               buffer alist)))
                (dp-tab-bar-select-tab buffer alist tab-name)))
            (let ((result (dp-action--display-in-tab
                           buffer alist)))
              (when result
                (car result))))
        (display-buffer-pop-up-frame buffer alist)))))

(defun dp-action--placed-p (alist)
  "Return non-nil if ALIST names a place for the buffer.
A window, a direction, a side, a slot, or a child frame named in ALIST is
a deliberate placement, left to the caller's own action functions.  A tab
or a frame that is not a child frame is asked about instead."
  (cl-some (lambda (key) (assq key alist))
           '(window direction side slot
             parent-frame child-frame-parameters)))

(defun dp-action-choose-window (buffer alist)
  "Display BUFFER in a window chosen with `ace-window'.
`disbuf-pivot-window-utility-choose-display-window' asks for the window: it asks again while the
chosen window cannot display BUFFER, and chooses nothing when no window
can answer.  The chosen window displays BUFFER through
`window--display-buffer' with ALIST, so the caller's entries -- a
`body-function' among them -- still take effect.  What
`disbuf-pivot-action-select' does with the selected window is its
own choice: `t' selects the chosen window, `auto' selects nothing, and
`nil' selects nothing now and selects the answering window again at the
end of the command."
  (let* ((aw-scope (cl-case (cdr (assq 'reusable-frames alist))
                     ((nil) 'frame)
                     (visible 'visible)
                     ((0 t) 'global)))
         (aw-ignore-current (or (cdr (assq 'inhibit-same-window alist))
                                (dp-window-utility-cannot-display-p (selected-window)))))
    (when-let* ((win (dp-window-utility-choose-display-window aw-scope aw-ignore-current)))
      (let ((answering (selected-window)))
        (window--display-buffer buffer win 'reuse alist)
        (pcase dp-action-select
          ('t (select-window win))
          ('nil (dp-window-utility-select-window-post-command answering))))
      win)))

(defun dp-action-split-or-ask (buffer alist)
  "Display BUFFER in a new window when a split is preferred, else ask.
`disbuf-pivot-window-utility-split-p' decides through `disbuf-pivot-window-utility-split-maximum' and its
two exclusion options.  When it says a split is preferred, try
`display-buffer-pop-up-window'; when that fails, and when the count is
not under the maximum, ask with `disbuf-pivot-action-choose-window'.
BUFFER and ALIST are passed to whichever of the two displays it."
  (or (and (dp-window-utility-split-p)
           (display-buffer-pop-up-window buffer alist))
      (dp-action-choose-window buffer alist)))

(defun dp-action--display (buffer alist)
  "Display BUFFER by the mode's rule.
When the call asks for a tab or a frame, ask which one, or a new one, and
display BUFFER there by the action functions.  Otherwise, unless ALIST
names a place for the buffer, call the functions of
`disbuf-pivot-action-functions' in order and return the first window
they display."
  (pcase (dp-action--target alist)
    ('tab (car-safe (dp-action-tab buffer alist)))
    ('frame (dp-action--frame buffer alist))
    (_
     (unless (dp-action--placed-p alist)
       (dp-action--run buffer alist)))))

(defun dp-action--rule ()
  "Return the entry `disbuf-pivot-action-mode' installs."
  (cons 'dp-action-control-p
        '(dp-action--display)))

(defun dp-action--install ()
  "Cons the mode's entry at the front of `display-buffer-alist'.
An entry `disbuf-pivot-action-control-p' already present is
replaced, so enabling an enabled mode leaves one entry."
  (setq display-buffer-alist
        (cons (dp-action--rule)
              (cl-remove 'dp-action-control-p
                         display-buffer-alist :key 'car))))

(defun dp-action--uninstall ()
  "Remove the mode's entry, and nothing else."
  (setq display-buffer-alist
        (cl-remove 'dp-action-control-p
                   display-buffer-alist :key 'car)))

;;;###autoload
(define-minor-mode dp-action-mode
  "Choose the window of a buffer the selected window cannot display.
When enabled, cons a `display-buffer-alist' entry at the front of the
list, matching every buffer an earlier entry does not take.  Priority is
list order: a popup manager's rule takes precedence for its buffers when
that manager's mode is enabled after this one, since its entry is then
consed above.  The entry's function displays a buffer in a window that
already displays it or in the selected window, then splits a new window
when `disbuf-pivot-window-utility-split-p' says a split is preferred, and otherwise asks
for a window with `ace-window', by the action functions
`disbuf-pivot-action-functions' lists in order.  A call that asks
for a tab or a frame -- through `tab-name', `tab-group',
`pop-up-frames', or a tab or frame action function in its ACTION -- is
asked which one, or a new one, then asked for the window inside it with
`aw-select', where the split dispatch keys split the chosen window.  A
request whose alist names a window, a direction, a side, a slot, or a
child frame is left to the caller's own action functions, and
`display-buffer-overriding-action' is consulted before the entry.
When disabled, remove that entry."
  :global t
  :group 'dp-action
  (if dp-action-mode
      (dp-action--install)
    (dp-action--uninstall)))

(provide 'disbuf-pivot)

;; Local Variables:
;; checkdoc-allow-quoting-nil-and-t: t
;; read-symbol-shorthands: (("dp-" . "disbuf-pivot-"))
;; End:

;;; disbuf-pivot.el ends here
