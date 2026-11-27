;;; disbuf-pivot.el --- Choose where to display a buffer the selected window cannot display  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/disbuf-pivot
;; Version: 0.1.0
;; Package-Requires: ((emacs "31.1") (ace-window "0"))
;; Keywords: convenience, windows
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; When the selected window cannot display a buffer -- it is dedicated
;; to another buffer or a side window -- the window the buffer goes to
;; is Emacs's choice, made by its default action functions, so the
;; buffer can go where the user does not expect it.
;; `disbuf-pivot-action-mode' replaces that with one rule and one
;; explicit choice.  By default `disbuf-pivot-action-functions' tries
;; `display-buffer-reuse-window', `display-buffer-same-window', and
;; `disbuf-pivot-action-choose-window', which opens the synchronous
;; dispatch prompt with window labels, explicit split actions, caller
;; intent, bypass pivot, and window-setting toggles.  A call that asks
;; for a tab or a frame asks which one, or a new one.  A tab asks for
;; its window when no window in it displays the buffer; an existing
;; frame asks for its tab when `tab-bar-mode' is active or it has more
;; than one, then for its window, while a new frame uses its selected
;; window.
;;
;; The mode conses one `display-buffer-alist' entry at the front of the
;; list, matched by every non-excluded buffer an earlier entry does not
;; take.  Priority is list order, and a package conses its entry at the
;; front when its mode is enabled, so enable a pop-up window manager's
;; mode after this one when its rule is to take precedence for its
;; buffers.  A request whose alist names a place for the buffer -- a
;; window, a direction, a side, a slot, a tab, or a frame -- is left to
;; the caller's own action functions.

(require 'cl-lib)
(require 'subr-x)
(require 'tab-bar)
(require 'dp-window-utility)
(require 'dp-tab-bar)

;;; Code:

(defgroup disbuf-pivot nil
  "Explicit buffer display management at the pivot."
  :group 'windows
  :prefix "disbuf-pivot-")

(defgroup dp-action nil
  "Choose where to display a buffer the selected window cannot display."
  :group 'disbuf-pivot
  :prefix "disbuf-pivot-action-")

(defcustom dp-reuse 'auto
  "How to handle a window that already displays the buffer.

`auto' reuses the matching window without prompting.

`ask' marks matching windows and shows the dispatch prompt with the
preferred reuse window as the dispatch prompt default.

Also applies to the `display-buffer-in-previous-window' fallback when
no previous window is usable."
  :type '(choice (const :tag "Reuse automatically" auto)
                 (const :tag "Ask with the dispatch prompt" ask))
  :group 'disbuf-pivot)

(defcustom dp-same-window-conflict 'ask
  "How to resolve a same-window request with `inhibit-same-window'.

`ask' reports the conflict and shows the dispatch prompt with the
selected window as the dispatch prompt default.

`same-window' reports the conflict and displays in the selected window
with `inhibit-same-window' bound to `nil'."
  :type '(choice (const :tag "Ask with the dispatch prompt" ask)
                 (const :tag "Use the selected window" same-window))
  :group 'disbuf-pivot)

(defcustom dp-header-info t
  "Which parts of header info appear in the dispatch prompt menu header.

`t' shows all three parts (`caller-intent', `source-entries', and
`window-facts') whenever non-empty.

`nil' hides all header info.

A list containing any subset of `caller-intent', `source-entries', and
`window-facts' shows only the listed parts.

The dispatch prompt default is always shown when present, regardless
of this option."
  :type '(choice (const :tag "Show all header info" t)
                 (const :tag "Hide header info" nil)
                 (set :tag "Selected parts"
                      (const :tag "Caller intent info" caller-intent)
                      (const :tag "Source-labeled entries" source-entries)
                      (const :tag "Window facts" window-facts)))
  :group 'disbuf-pivot)

(defcustom dp-exclude-conditions nil
  "List of `buffer-match-p' conditions for excluded buffers.
A buffer matching any condition here is not regulated by the package's
`display-buffer-alist' entry: `disbuf-pivot-action-control-p' returns
`nil' so later `display-buffer-alist' entries and Emacs display actions
handle it instead.

Each element is any condition accepted by `buffer-match-p', including a
regexp, `(derived-mode . MODE)', `(major-mode . MODE)',
`(category . SYMBOL)', `(this-command . COMMAND)', a predicate
function, or a `not', `and', or `or' expression.  The caller's ACTION
is passed as the third argument to `buffer-match-p' so `category'
conditions match."
  :type '(repeat (choice (regexp :tag "Buffer name regexp")
                         (function :tag "Predicate function")
                         (sexp :tag "Condition expression")))
  :group 'disbuf-pivot)

(defcustom dp-action-select 'auto
  "Whether the action selects the chosen window after a prompt.

`auto' honors the caller and `post-command-select-window':
`pop-to-buffer' selects the window it displays, and a caller that does
not select leaves the selected window unchanged.

`t' selects the chosen window after displaying the buffer.

`nil' restores the previously selected window at the end of the command,
the way `display-buffer' treats a `nil' `post-command-select-window'
entry."
  :type '(choice (const :tag "Let the caller decide" auto)
                 (const :tag "Always select" t)
                 (const :tag "Never select" nil))
  :group 'dp-action)

(defcustom dp-action-functions
  '(display-buffer-reuse-window
    display-buffer-same-window
    dp-action-choose-window)
  "The action functions the mode's entry tries, in order.
Each is called with the buffer and the action alist, and the first one
that returns a non-nil result decides the display.  The default shows a
buffer in a window that already displays it, else in the selected
window, and otherwise opens the dispatch prompt via
`disbuf-pivot-action-choose-window'.

An action function can be added, dropped, or reordered here: putting
`display-buffer-same-window' first gives a buffer that another window
already displays a second window, and dropping
`disbuf-pivot-action-choose-window' removes the dispatch prompt.  A
request whose alist names a place for the buffer -- a window, a
direction, a side, a slot, or a child frame -- is left to the caller's
own action functions before any function here is tried; a call that
asks for a tab or a frame asks which one first, then runs the dispatch
prompt inside it."
  :type '(choice (function :tag "One action function")
                 (repeat :tag "Action functions" function))
  :group 'dp-action)

(defvar dp-action--action nil
  "The ACTION argument of the `display-buffer' call being decided.
`disbuf-pivot-action--display' binds this dynamically from the active
`display-buffer' call frame on the stack so nested `display-buffer'
calls cannot clobber an outer call's ACTION.")

(defun dp-action--unwrapped-display-buffer ()
  "Return the underlying function definition of `display-buffer'."
  (let ((fn (symbol-function 'display-buffer)))
    (if (fboundp 'advice--cd*r)
        (advice--cd*r fn)
      fn)))

(defconst dp-action--orig-display-buffer
  (dp-action--unwrapped-display-buffer)
  "Underlying `display-buffer' definition captured when loaded.")

(defun dp-action--stack-caller-action ()
  "Return `(t . ACTION)' for the innermost active `display-buffer' call.
Return `nil' when no `display-buffer' call is active on the stack.
Non-list or improper ACTION values are normalized to `nil' to match what
`display-buffer' passes to `display-buffer-alist' conditions."
  (let ((orig (dp-action--unwrapped-display-buffer)))
    (catch 'dp-action--found
      (mapbacktrace
       (lambda (evald func args _flags)
         (when (and evald
                    (or (eq func 'display-buffer)
                        (eq func orig)
                        (eq func dp-action--orig-display-buffer)))
           (let ((act (nth 1 args)))
             (throw 'dp-action--found
                    (cons t (and (proper-list-p act) act)))))))
      nil)))

(defun dp-action--current-action ()
  "Return the caller's ACTION for the current display call.
When running inside `display-buffer', read the innermost active
`display-buffer' call frame without mutating `display-buffer-alist'.
Otherwise return `disbuf-pivot-action--action'."
  (if-let* ((found (dp-action--stack-caller-action)))
      (cdr found)
    dp-action--action))

(defun dp-action--excluded-p (buffer action)
  "Return non-nil if BUFFER and ACTION are excluded.
Checks `disbuf-pivot-exclude-conditions' with `buffer-match-p', passing
ACTION as the third argument."
  (when (and dp-exclude-conditions
             buffer
             (or (bufferp buffer) (stringp buffer))
             (buffer-live-p (get-buffer buffer)))
    (let ((act (and (proper-list-p action) action)))
      (cl-some (lambda (condition)
                 (and condition
                      (buffer-match-p condition buffer act)))
               dp-exclude-conditions))))

(defun dp-action-control-p (buffer action)
  "Match every non-excluded buffer an earlier entry does not take.
This is the condition of the entry `disbuf-pivot-action-mode'
installs, so the mode's function is tried after earlier
`display-buffer-alist' entries and before the caller's ACTION argument,
the special action, `display-buffer-base-action', and the fallback
action.  Return `nil' when BUFFER and ACTION match
`disbuf-pivot-exclude-conditions'; otherwise return non-nil."
  (not (dp-action--excluded-p buffer action)))

(defun dp-action--functions (action)
  "Return the action functions ACTION names, as a list."
  (let ((functions (car-safe action)))
    (cond ((functionp functions) (list functions))
          ((proper-list-p functions) functions))))

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

(defun dp-action--alist-entry-sources (alist)
  "Return an alist mapping present window-setting keys in ALIST to source labels.
Entries coming from the caller's ACTION map to nil (omitted in toggle
labels); entries from `display-buffer-overriding-action',
`display-buffer-base-action', or `display-buffer-fallback-action' map
to their source label."
  (let ((ov-alist (cdr-safe display-buffer-overriding-action))
        (caller-alist (cdr-safe dp-action--action))
        (base-alist (cdr-safe display-buffer-base-action))
        (fb-alist (cdr-safe display-buffer-fallback-action))
        (sources nil))
    (dolist (spec dp-window-utility--window-setting-specs)
      (let ((key (car spec)))
        (when (alist-get key alist)
          (let ((src (cond
                      ((assq key ov-alist) "overriding action")
                      ((assq key caller-alist) nil)
                      ((assq key base-alist) "base action")
                      ((assq key fb-alist) "fallback action"))))
            (when src
              (push (cons key src) sources))))))
    (nreverse sources)))

(defun dp-action--apply-selection (chosen answering)
  "Apply `disbuf-pivot-action-select' to CHOSEN window and ANSWERING window."
  (pcase dp-action-select
    ('t (when (window-live-p chosen) (select-window chosen)))
    ('nil (dp-window-utility-select-window-post-command answering))))

(defun dp-action--run-caller-intent (buffer alist)
  "Run the caller's function list for BUFFER with ALIST under recursion guard.
Return the first non-nil result from the caller's functions, or `nil' if
every function returns `nil'."
  (let ((dp-window-utility--in-prompt t)
        (fns (dp-action--functions dp-action--action)))
    (cl-some (lambda (fn) (funcall fn buffer alist)) fns)))

(defun dp-action--display-in-tab (buffer alist)
  "Display BUFFER in the selected tab, reusing a window or prompting.
A window of the selected frame that already displays BUFFER is used
first, unless ALIST's `inhibit-same-window' names the selected window.
Otherwise run the dispatch prompt via
`disbuf-pivot-window-utility-choose-tab-window' and display BUFFER in
the chosen or newly split window.  Return `(WINDOW . TYPE)',
`(fail . fail)' when left undisplayed, or `nil' on bypass or in a
cannot-prompt context."
  (let ((window (get-buffer-window buffer (selected-frame)))
        (inhibit-same (alist-get 'inhibit-same-window alist)))
    (if (and window
             (not (and inhibit-same (eq window (selected-window)))))
        (progn
          (window--display-buffer buffer window 'reuse alist)
          (cons window 'reuse))
      (let ((answering (selected-window))
            (sources (dp-action--alist-entry-sources alist))
            (feedback nil)
            (done nil)
            (outcome nil))
        (while (not done)
          (let* ((fb feedback)
                 (res (progn
                        (setq feedback nil)
                        (dp-window-utility-choose-tab-window
                         alist buffer
                         :sources sources
                         :initial-feedback fb))))
            (pcase (plist-get res :action)
              ('window
               (let* ((win (plist-get res :window))
                      (eff (plist-get res :alist))
                      (disp-alist (if (eq win answering)
                                      (cons '(inhibit-same-window . nil) eff)
                                    eff)))
                 (if (window-live-p win)
                     (progn
                       (window--display-buffer buffer win 'reuse disp-alist)
                       (dp-action--apply-selection win answering)
                       (setq outcome (cons win 'reuse)
                             done t))
                   (setq feedback
                         "disbuf-pivot: chosen window is no longer live")
                   (message "%s" feedback))))
              ('split
               (let ((win (plist-get res :window))
                     (eff (plist-get res :alist)))
                 (if (window-live-p win)
                     (progn
                       (window--display-buffer buffer win 'window eff)
                       (dp-action--apply-selection win answering)
                       (setq outcome (cons win 'window)
                             done t))
                   (setq feedback
                         "disbuf-pivot: chosen window is no longer live")
                   (message "%s" feedback))))
              ('leave-undisplayed
               (setq outcome (cons 'fail 'fail)
                     done t))
              (_
               (setq outcome nil
                     done t)))))
        outcome))))

(defun dp-action-tab (buffer alist)
  "Display BUFFER in a tab, asking which and in which window.
When `reusable-frames' is non-nil, use `tab-bar-get-buffer-tab' first,
as `display-buffer-in-tab' does, and select the tab that already
displays BUFFER.  Otherwise read a name with
`disbuf-pivot-action--read-tab-name' and select or make that tab.
In the tab, reuse a window that already displays BUFFER; if there is
none, run the dispatch prompt.  ALIST is the action alist of the
display.  Return `(WINDOW . TYPE)' (`reuse' for an existing tab, `tab'
for a new one, or `fail' when left undisplayed), or `nil' in a
cannot-prompt context."
  (unless (dp-window-utility-cannot-prompt-p)
    (let ((reusable (and (alist-get 'reusable-frames alist)
                         (tab-bar-get-buffer-tab
                          buffer
                          (alist-get 'reusable-frames alist)
                          (alist-get 'ignore-current-tab alist)))))
      (if reusable
          (progn
            (let ((dp-window-utility--in-prompt t)
                  (frame (alist-get 'frame reusable))
                  (index (alist-get 'index reusable)))
              (when frame
                (select-frame-set-input-focus frame))
              (when index
                (tab-bar-select-tab (1+ index))))
            (dp-action--display-in-tab buffer alist))
        (let* ((type
                (let ((dp-window-utility--in-prompt t))
                  (let ((name (dp-action--read-tab-name buffer alist)))
                    (dp-tab-bar-select-tab buffer alist name))))
               (result (dp-action--display-in-tab buffer alist)))
          (when result
            (if (eq (car result) 'fail)
                result
              (cons (car result)
                    (if (eq type 'tab) 'tab (cdr result))))))))))

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

(defun dp-action--ask-tab-p ()
  "Return non-nil when the frame prompt should read a tab name.
Ask when `tab-bar-mode' is active, so the prompt can make a new tab even
when the frame has one tab.  Also ask when the frame already has more
than one tab."
  (or (bound-and-true-p tab-bar-mode)
      (> (length (tab-bar-tabs)) 1)))

(defun dp-action--frame (buffer alist)
  "Display BUFFER in a frame, asking which frame and which window.
Read a frame name; an existing name selects that frame, a new name makes
a new frame with that name, and an empty name makes a new frame with
the default name.  Selecting a frame gives it focus unless
`inhibit-switch-frame'.  Read a tab name when `tab-bar-mode' is active or
the frame has more than one tab, and select or make that tab.  Then reuse
a window of the tab that already displays BUFFER, or run the dispatch
prompt.  ALIST is passed to the action functions.  Return the window, or
`nil' in a cannot-prompt context."
  (unless (dp-window-utility-cannot-prompt-p)
    (let* ((frames (dp-action--frames alist))
           (candidates (dp-action--frame-candidates frames))
           (names (mapcar #'car candidates))
           (name (let ((dp-window-utility--in-prompt t))
                   (completing-read
                    "Frame (empty or a new name for a new frame): "
                    names nil nil)))
           (frame (cdr (assoc-string name candidates))))
      (if frame
          (progn
            (let ((dp-window-utility--in-prompt t))
              (if (alist-get 'inhibit-switch-frame alist)
                  (select-frame frame)
                (select-frame-set-input-focus frame))
              (when (dp-action--ask-tab-p)
                (let ((tab-name (dp-action--read-tab-name
                                 buffer alist)))
                  (dp-tab-bar-select-tab buffer alist tab-name))))
            (let ((result (dp-action--display-in-tab
                           buffer alist)))
              (when result
                (car result))))
        (let ((dp-window-utility--in-prompt t))
          (let ((window (display-buffer-pop-up-frame buffer alist)))
            (when (and window (not (string-empty-p name)))
              (set-frame-parameter (window-frame window) 'name name))
            window))))))

(defun dp-action--placed-p (alist)
  "Return non-nil if ALIST names a place for the buffer.
A window, a direction, a side, a slot, or a child frame named in ALIST is
a deliberate placement, left to the caller's own action functions.  A tab
or a frame that is not a child frame is asked about instead."
  (cl-some (lambda (key) (assq key alist))
           '(window direction side slot
             parent-frame child-frame-parameters)))

(defun dp-action-choose-window (buffer alist)
  "Display BUFFER via the synchronous dispatch prompt.
Runs `disbuf-pivot-window-utility-dispatch-prompt' for BUFFER and ALIST.
A chosen window displays BUFFER with `window--display-buffer' type
`reuse' (binding `inhibit-same-window' to `nil' if the selected window
is chosen); a split action displays BUFFER in the new window with type
`window'.  \"Use caller intent\" runs the caller's function list with
the prompt's local toggled alist under the recursion guard, reopening
the dispatch prompt if every caller function returns `nil'.  \"Leave
undisplayed\" returns `fail', and \"Bypass pivot\" returns `nil'.
`disbuf-pivot-action-select' controls post-choice window selection."
  (let* ((answering (selected-window))
         (caller-fns (dp-action--functions dp-action--action))
         (caller-action (when caller-fns
                          '(:label "Use caller intent" :action caller-intent)))
         (sources (dp-action--alist-entry-sources alist))
         (facts (when (dp-window-utility-cannot-display-p answering buffer)
                  '("selected window cannot display")))
         (header-info (when facts (list :window-facts facts)))
         (feedback nil)
         (done nil)
         (outcome nil))
    (while (not done)
      (let* ((fb feedback)
             (res (progn
                    (setq feedback nil)
                    (dp-window-utility-dispatch-prompt
                     buffer alist
                     :caller-action caller-action
                     :header-info header-info
                     :sources sources
                     :initial-feedback fb))))
        (pcase (plist-get res :action)
          ('window
           (let* ((win (plist-get res :window))
                  (eff (plist-get res :alist))
                  (disp-alist (if (eq win answering)
                                  (cons '(inhibit-same-window . nil) eff)
                                eff)))
             (if (window-live-p win)
                 (progn
                   (window--display-buffer buffer win 'reuse disp-alist)
                   (dp-action--apply-selection win answering)
                   (setq outcome win
                         done t))
               (setq feedback
                     "disbuf-pivot: chosen window is no longer live")
               (message "%s" feedback))))
          ('split
           (let ((win (plist-get res :window))
                 (eff (plist-get res :alist)))
             (if (window-live-p win)
                 (progn
                   (window--display-buffer buffer win 'window eff)
                   (dp-action--apply-selection win answering)
                   (setq outcome win
                         done t))
               (setq feedback
                     "disbuf-pivot: chosen window is no longer live")
               (message "%s" feedback))))
          ('caller-intent
           (let ((caller-res (dp-action--run-caller-intent
                              buffer (plist-get res :alist))))
             (if caller-res
                 (setq outcome caller-res
                       done t)
               (setq feedback
                     "disbuf-pivot: caller's action functions returned nil")
               (message "%s" feedback))))
          ('leave-undisplayed
           (setq outcome 'fail
                 done t))
          (_
           (setq outcome nil
                 done t)))))
    outcome))

(defun dp-action--display (buffer alist)
  "Display BUFFER by the mode's rule.
Return `nil' in a cannot-prompt context.  When the call asks for a tab
or a frame, ask which one, or a new one, and display BUFFER there by the
action functions.  Otherwise, unless ALIST names a place for the buffer,
call the functions of `disbuf-pivot-action-functions' in order and
return the first window they display."
  (unless (dp-window-utility-cannot-prompt-p)
    (let ((dp-action--action (dp-action--current-action)))
      (pcase (dp-action--target alist)
        ('tab (car-safe (dp-action-tab buffer alist)))
        ('frame (dp-action--frame buffer alist))
        (_
         (unless (dp-action--placed-p alist)
           (dp-action--run buffer alist)))))))

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
list, matching every non-excluded buffer an earlier entry does not take;
see `disbuf-pivot-exclude-conditions'.  Priority is list order: a pop-up
window manager's rule takes precedence for its buffers when that
manager's mode is enabled after this one, since its entry is then consed
above.  By default `disbuf-pivot-action-functions' reuses a window that
already displays the buffer, uses the selected window when displayable,
and otherwise opens the synchronous dispatch prompt (with window labels,
explicit split actions, caller intent, bypass pivot, and window-setting
toggles).  A call that asks for a tab or a frame -- through `tab-name',
`tab-group', `pop-up-frames', or a tab or frame action function in its
ACTION -- asks which one, or a new one, then runs the dispatch prompt
inside it.  A request whose alist names a window, a direction, a side, a
slot, or a child frame is left to the caller's own action functions, and
`display-buffer-overriding-action' is consulted before the entry.  When
disabled, remove that entry."
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
