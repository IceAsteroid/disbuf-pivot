;;; disbuf-pivot.el --- Explicit buffer display management at the pivot  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/disbuf-pivot
;; Version: 0.1.0
;; Package-Requires: ((emacs "31.1") (ace-window "0"))
;; Keywords: convenience, windows
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; `disbuf-pivot' replaces an implicit `display-buffer' choice with an
;; explicit one.  `disbuf-pivot-action-mode' conses one
;; `display-buffer-alist' entry at the front of the list for every
;; non-excluded buffer an earlier entry does not take.  It classifies
;; the effective intent (all 19 Emacs 31.1 `display-buffer-*'
;; action functions, reuse-first chains such as
;; `display-buffer--other-frame-action', non-list ACTION values, and
;; dynamic `pop-up-frames' / `display-buffer-reuse-frames'): fixed-place
;; and uncovered functions are respected (returning nil),
;; `display-buffer-no-window' with `allow-no-window' returns `fail', tab
;; and frame intents run the tab or frame prompt, silent reuse/same-window
;; rules display directly with exact `window--display-buffer' TYPE
;; propagation, and all other regulated intents open the synchronous
;; dispatch prompt with header info, window labels, explicit split
;; actions, window-setting toggles, caller intent, and bypass pivot.
;;
;; Priority is list order: enable `disbuf-pivot-action-mode' first and
;; any pop-up window manager (such as `column-popup' or `popper') second
;; so its entry sits above this package's entry.

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
  "Choose where to display a buffer at the pivot."
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
  "The action functions tried in order for no-preference calls.
Each is called with the buffer and the combined action alist, and the
first one that returns a non-nil result decides the display.
`display-buffer-reuse-window' and `display-buffer-same-window' are
dispatched through the package's regulated handlers so
`disbuf-pivot-reuse' and the per-buffer displayable predicate apply
regardless of list order.

An action function can be added, dropped, or reordered here: putting
`display-buffer-same-window' first gives a buffer that another window
already displays a second window, and dropping
`disbuf-pivot-action-choose-window' removes the dispatch prompt."
  :type '(choice (function :tag "One action function")
                 (repeat :tag "Action functions" function))
  :group 'dp-action)

(defconst dp-action--respect-functions
  '(display-buffer-in-side-window
    display-buffer-in-atom-window
    display-buffer-in-child-frame)
  "Action functions respected by returning `nil' without prompting.")

(defconst dp-action--tab-functions
  '(display-buffer-in-tab
    display-buffer-in-new-tab)
  "Action functions classified as tab intents.")

(defconst dp-action--frame-functions
  '(display-buffer-pop-up-frame
    display-buffer-use-some-frame)
  "Action functions classified as frame intents.")

(defconst dp-action--reuse-functions
  '(display-buffer-reuse-window
    display-buffer-reuse-mode-window)
  "Action functions handled as reuse-first chains.")

(defconst dp-action--relative-functions
  '(display-buffer-in-direction
    display-buffer-below-selected
    display-buffer-at-bottom)
  "Action functions classified as relative placement intents.")

(defconst dp-action--strategy-functions
  '(display-buffer-same-window
    display-buffer-reuse-window
    display-buffer-reuse-mode-window
    display-buffer-pop-up-window
    display-buffer-in-previous-window
    display-buffer-use-some-window
    display-buffer-use-least-recent-window
    display-buffer-full-frame)
  "Action functions classified as strategy intents.")

(defconst dp-action--covered-functions
  (append dp-action--respect-functions
          dp-action--tab-functions
          dp-action--frame-functions
          dp-action--relative-functions
          dp-action--strategy-functions
          '(display-buffer-no-window))
  "All 19 Emacs 31.1 `display-buffer-*' action functions covered by the spec.")

(defvar dp-action--action nil
  "The ACTION argument of the `display-buffer' call being decided.
`disbuf-pivot-action--display' binds this dynamically from the active
`display-buffer' call frame on the stack so nested `display-buffer'
calls cannot clobber an outer call's ACTION.")

(defvar dp-action--extra-action nil
  "The synthesized `extra-action' of the active `display-buffer' call.
`disbuf-pivot-action--display' binds this dynamically alongside
`disbuf-pivot-action--action' from the same backtrace walk so
`disbuf-pivot-action--alist-entry-source' can distinguish `extra action'
entries from `display-buffer-base-action' in exact Emacs precedence.")

(defvar dp-action--in-run nil
  "Non-nil while `disbuf-pivot-action--run' loops over action functions.
Allows a bypass choice (`M-b') inside a regulated handler to stop
`disbuf-pivot-action--run' immediately and return `nil' to
`display-buffer' instead of running later functions in the list.")

;;; Stack-based caller's ACTION lookup and exclusion gate

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
`display-buffer' passes to `display-buffer-alist' conditions.  When
`disbuf-pivot-action--extra-action' is dynamically bound to `capture',
record the call's synthesized extra-action alist there in the same walk."
  (let ((orig (dp-action--unwrapped-display-buffer)))
    (catch 'dp-action--found
      (mapbacktrace
       (lambda (evald func args _flags)
         (when (and evald
                    (or (eq func 'display-buffer)
                        (eq func orig)
                        (eq func dp-action--orig-display-buffer)))
           (let ((act (nth 1 args))
                 (frame (nth 2 args)))
             (when (eq dp-action--extra-action 'capture)
               (let ((extra (append (when (and act (not (listp act)))
                                      '((inhibit-same-window . t)))
                                    (when frame
                                      (list (cons 'reusable-frames frame))))))
                 (setq dp-action--extra-action (and extra (cons nil extra)))))
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

;;; Emacs 31.1 reuse and previous-window finders

(defun dp-action--resolve-reusable-frames (alist)
  "Resolve the frames argument for reuse search from ALIST.
Honors `reusable-frames' in ALIST first, then `(window--pop-up-frames
alist)', then `display-buffer-reuse-frames', defaulting to
`last-nonminibuffer-frame'."
  (let ((entry (assq 'reusable-frames alist)))
    (cond (entry (cdr entry))
          ((window--pop-up-frames alist) 0)
          ((with-suppressed-warnings ((obsolete display-buffer-reuse-frames))
             display-buffer-reuse-frames)
           0)
          (t (last-nonminibuffer-frame)))))

(defun dp-action--find-reuse-windows (buffer alist)
  "Find windows already displaying BUFFER under ALIST.
Honors `reusable-frames', `(window--pop-up-frames alist)',
`display-buffer-reuse-frames', `reuse-indirect', and
`inhibit-same-window'.  Return `(PREFERRED . ALL-MATCHES)' where
PREFERRED favors a window on the selected frame, or `nil' if none
matches."
  (let* ((frames (dp-action--resolve-reusable-frames alist))
         (reuse-indirect (alist-get 'reuse-indirect alist))
         (inhibit-same (alist-get 'inhibit-same-window alist))
         (this-frame (selected-frame))
         (raw (get-buffer-window-list buffer 'nomini frames reuse-indirect))
         (matches (if inhibit-same
                      (delq (selected-window) raw)
                    raw)))
    (when matches
      (let ((preferred
             (cond
              ((and (eq buffer (window-buffer (selected-window)))
                    (not inhibit-same)
                    (memq (selected-window) matches))
               (selected-window))
              ((eq (window-frame (car matches)) this-frame)
               (car matches))
              ((cl-find-if (lambda (w) (eq (window-frame w) this-frame))
                           (cdr matches)))
              (t (car matches)))))
        (cons preferred matches)))))

(defun dp-action--find-reuse-mode-windows (buffer alist)
  "Find windows matching the required major mode for BUFFER and ALIST.
Matches Emacs 31.1 `display-buffer-reuse-mode-window' 4-tier priority
\(same-mode same-frame, same-mode other-frame, derived-mode same-frame,
derived-mode other-frame).  Defaults `mode' to BUFFER's `major-mode'
when omitted.  Return `(PREFERRED . ALL-MATCHES)' or `nil'."
  (let* ((frames (dp-action--resolve-reusable-frames alist))
         (mode-entry (assq 'mode alist))
         (allowed-modes
          (ensure-list
           (if mode-entry
               (cdr mode-entry)
             (with-current-buffer buffer major-mode))))
         (inhibit-same (alist-get 'inhibit-same-window alist))
         (curwin (selected-window))
         (curframe (selected-frame))
         (windows (window-list-1 nil 'nomini frames))
         same-same same-other derived-same derived-other)
    (dolist (win windows)
      (let ((kind (with-current-buffer (window-buffer win)
                    (cond ((memq major-mode allowed-modes) 'same)
                          ((derived-mode-p allowed-modes) 'derived)))))
        (when (and kind
                   (dp-window-utility-displayable-p win buffer)
                   (not (and inhibit-same (eq win curwin))))
          (if (eq curframe (window-frame win))
              (if (eq kind 'same)
                  (push win same-same)
                (push win derived-same))
            (if (eq kind 'same)
                (push win same-other)
              (push win derived-other))))))
    (let ((ordered (nconc same-same same-other derived-same derived-other)))
      (when ordered
        (cons (car ordered) ordered)))))

(defun dp-action--dereference-previous-window (alist)
  "Return the resolved `previous-window' entry from ALIST, or `nil'.
Dereferences bound variable symbols, matching Emacs 31.1
`display-buffer-in-previous-window'."
  (let ((pw (alist-get 'previous-window alist)))
    (when (and pw (symbolp pw) (boundp pw))
      (setq pw (symbol-value pw)))
    (and (window-live-p pw) pw)))

(defun dp-action--find-previous-windows (buffer alist)
  "Find usable previous windows for BUFFER under ALIST.
Checks `window-prev-buffers' across reusable frames and gives precedence
to any explicit `previous-window' entry (dereferencing bound variable
symbols).  Return a plist `(:preferred WIN :explicit-p BOOL :matches
LIST)' or `nil' when no previous window is usable."
  (let* ((frames (dp-action--resolve-reusable-frames alist))
         (inhibit-same (alist-get 'inhibit-same-window alist))
         (curwin (selected-window))
         (prev-win (dp-action--dereference-previous-window alist))
         (matches nil)
         best second-best explicit-p)
    (dolist (win (window-list-1 (frame-first-window) 'nomini frames))
      (when (and (assq buffer (window-prev-buffers win))
                 (dp-window-utility-displayable-p win buffer))
        (if (eq win curwin)
            (unless inhibit-same
              (push win matches)
              (unless second-best (setq second-best win)))
          (push win matches)
          (unless best (setq best win)))))
    (when (and prev-win
               (dp-window-utility-displayable-p prev-win buffer))
      (if (eq prev-win curwin)
          (unless inhibit-same
            (setq second-best prev-win
                  explicit-p (not best))
            (cl-pushnew prev-win matches))
        (setq best prev-win
              explicit-p t)
        (cl-pushnew prev-win matches)))
    (when-let* ((preferred (or best second-best)))
      (list :preferred preferred
            :explicit-p explicit-p
            :matches (nreverse matches)))))

;;; Header info, effect phrases, and source-labeled entries

(defun dp-action--alist-entry-source (key alist)
  "Return the source label for KEY in ALIST, or `nil' if from caller's ACTION.
Returns `\"overriding action\"', `nil' (caller), `\"extra action\"',
`\"base action\"', or `\"fallback action\"' in Emacs `display-buffer'
precedence order when KEY is present in ALIST."
  (when-let* ((cell (assq key alist)))
    (let ((val (cdr cell)))
      (cl-flet ((matches-source-p (action)
                  (when-let* ((c (assq key (cdr-safe action))))
                    (equal (cdr c) val))))
        (cond
         ((matches-source-p display-buffer-overriding-action)
          "overriding action")
         ((matches-source-p dp-action--action)
          nil)
         ((matches-source-p dp-action--extra-action)
          "extra action")
         ((matches-source-p display-buffer-base-action)
          "base action")
         ((matches-source-p display-buffer-fallback-action)
          "fallback action")
         (t "extra action"))))))

(defun dp-action--alist-entry-sources (alist)
  "Return an alist mapping present window-setting keys in ALIST to source labels.
Entries coming from the caller's ACTION map to nil (omitted in toggle
labels); entries from other actions map to their source label."
  (let ((sources nil))
    (dolist (spec dp-window-utility--window-setting-specs)
      (let ((key (car spec)))
        (when (alist-get key alist)
          (when-let* ((src (dp-action--alist-entry-source key alist)))
            (push (cons key src) sources)))))
    (nreverse sources)))

(defun dp-action--article-for-number (n)
  "Return the English indefinite article (`\"an\"' or `\"a\"') for integer N."
  (let ((s (number-to-string (abs n))))
    (if (or (string-prefix-p "8" s)
            (member s '("11" "18")))
        "an"
      "a")))

(defun dp-action--window-setting-effect (key val)
  "Return the Section 9 effect phrase for window-setting KEY and VAL."
  (when val
    (pcase key
      ('dedicated "dedicated")
      ('window-parameters "window parameters")
      ('preserve-size
       (when (consp val)
         (cond ((and (car val) (cdr val)) "preserve size")
               ((car val) "preserve width")
               ((cdr val) "preserve height"))))
      ('window-height
       (cond ((integerp val)
              (format "%s %d-line window"
                      (dp-action--article-for-number val) val))
             ((floatp val) (format "%d%% of the frame high" (round (* val 100))))
             ((and (consp val) (eq (car val) 'body-lines) (integerp (cdr val)))
              (format "a window with %s %d-line body"
                      (dp-action--article-for-number (cdr val)) (cdr val)))
             ((symbolp val) (symbol-name val))
             (t "custom height")))
      ('window-width
       (cond ((integerp val)
              (format "%s %d-column window"
                      (dp-action--article-for-number val) val))
             ((floatp val) (format "%d%% of the frame wide" (round (* val 100))))
             ((and (consp val) (eq (car val) 'body-columns) (integerp (cdr val)))
              (format "%s %d-column body"
                      (dp-action--article-for-number (cdr val)) (cdr val)))
             ((symbolp val) (symbol-name val))
             (t "custom width")))
      ('window-size
       (cond ((and (consp val) (eq (car val) 'body-chars)
                   (consp (cdr val))
                   (integerp (cadr val)) (integerp (cddr val)))
              (format "a new frame with %s %d by %d body"
                      (dp-action--article-for-number (cadr val))
                      (cadr val) (cddr val)))
             ((and (consp val) (integerp (car val)) (integerp (cdr val)))
              (format "a new frame %d columns by %d lines" (car val) (cdr val)))
             ((symbolp val) (symbol-name val))
             (t "custom frame size"))))))

(defun dp-action--function-effect-phrase (fn &optional alist)
  "Return the Section 9 user-facing effect phrase for action function FN.
ALIST provides parameter details such as `direction' or `previous-window'."
  (pcase fn
    ('display-buffer-same-window "same window")
    ('display-buffer-reuse-window "reuse")
    ('display-buffer-reuse-mode-window "reuse")
    ('display-buffer-pop-up-window "new window")
    ('display-buffer-in-previous-window
     (if-let* ((pw (dp-action--dereference-previous-window alist)))
         (format "previous window %s" (buffer-name (window-buffer pw)))
       "a window that previously showed the buffer"))
    ('display-buffer-use-some-window "some window")
    ('display-buffer-use-least-recent-window "a recently unused window")
    ('display-buffer-in-direction
     (format "direction %s" (or (alist-get 'direction alist) "unspecified")))
    ('display-buffer-below-selected "below the selected window")
    ('display-buffer-at-bottom "at the bottom of the frame")
    ('display-buffer-full-frame "full frame, other windows will be deleted")
    ('display-buffer-pop-up-frame "new frame")
    ('display-buffer-use-some-frame "existing frame")
    ('display-buffer-in-tab "existing tab")
    ('display-buffer-in-new-tab "new tab")
    ('display-buffer-no-window "no window")
    ('display-buffer-in-child-frame "child frame")
    ('display-buffer-in-side-window "side window")
    ('display-buffer-in-atom-window "atom window")
    ((pred symbolp) (symbol-name fn))
    (_ "custom action")))

(defun dp-action--format-caller-intent-info (primary-phrase caller-fns &optional _alist)
  "Format the caller intent info string for PRIMARY-PHRASE and CALLER-FNS.
Uses `Caller (<category>): ...' when `(category . SYMBOL)' is present in
the caller's ACTION, appends caller window-setting effects in Section 9
order, and appends each later function in CALLER-FNS after `; else '."
  (let* ((caller-alist (cdr-safe dp-action--action))
         (cat (alist-get 'category caller-alist))
         (prefix (if (and cat (symbolp cat))
                     (format "Caller (%s): " cat)
                   "Caller: "))
         (parts (list primary-phrase)))
    ;; Self-contradictory same-window + caller inhibit-same-window.
    (when (and (memq 'display-buffer-same-window caller-fns)
               (alist-get 'inhibit-same-window caller-alist))
      (push "inhibit same window" parts))
    ;; Caller window-setting effects in fixed Section 9 order.
    (dolist (spec dp-window-utility--window-setting-specs)
      (let* ((key (car spec))
             (val (alist-get key caller-alist)))
        (when-let* ((eff (dp-action--window-setting-effect key val)))
          (push eff parts))))
    (let ((head (concat prefix (mapconcat #'identity (nreverse parts) ", ")))
          (fallbacks (cdr-safe caller-fns)))
      (if fallbacks
          (concat head
                  (mapconcat
                   (lambda (fn)
                     (concat "; else "
                             (dp-action--function-effect-phrase
                              fn caller-alist)))
                   fallbacks ""))
        head))))

(defun dp-action--format-source-entries
    (alist &optional include-inhibit-same caller-fns)
  "Format source-labeled entries for non-caller entries in ALIST.
When INCLUDE-INHIBIT-SAME is non-nil and `inhibit-same-window' comes
from a non-caller source, include `<source>: inhibit same window'.
CALLER-FNS enables source reporting for rule-specific non-caller entries
such as `direction' and `previous-window'."
  (let ((by-source nil))
    (cl-flet ((add-entry (src eff)
                (let ((cell (assoc src by-source)))
                  (if cell
                      (setcdr cell (append (cdr cell) (list eff)))
                    (push (list src eff) by-source)))))
      (when (and include-inhibit-same (alist-get 'inhibit-same-window alist))
        (when-let* ((src (dp-action--alist-entry-source
                          'inhibit-same-window alist)))
          (add-entry src "inhibit same window")))
      (when (and (memq 'display-buffer-in-direction caller-fns)
                 (alist-get 'direction alist))
        (when-let* ((src (dp-action--alist-entry-source 'direction alist)))
          (add-entry src (format "direction %s" (alist-get 'direction alist)))))
      (when (memq 'display-buffer-in-previous-window caller-fns)
        (when-let* ((pw (dp-action--dereference-previous-window alist))
                    (src (dp-action--alist-entry-source
                          'previous-window alist)))
          (add-entry src (format "previous window %s"
                                 (buffer-name (window-buffer pw))))))
      (dolist (spec dp-window-utility--window-setting-specs)
        (let* ((key (car spec))
               (val (alist-get key alist)))
          (when val
            (when-let* ((src (dp-action--alist-entry-source key alist))
                        (eff (dp-action--window-setting-effect key val)))
              (add-entry src eff))))))
    (mapcar (lambda (entry)
              (format "%s: %s" (car entry)
                      (mapconcat #'identity (cdr entry) ", ")))
            (nreverse by-source))))

(defun dp-action--format-window-list-fact (windows &optional frame)
  "Format a window-fact string describing reuse WINDOWS relative to FRAME."
  (when windows
    (let* ((target-frame (or frame (selected-frame)))
           (scope-wins (dp-window-utility--scope-windows target-frame))
           (valid-splits
            (let ((seen nil) (out nil))
              (dolist (item dp-split-actions)
                (when (and (consp item)
                           (dp-window-utility--valid-split-key-p (car item))
                           (not (memq (car item) seen))
                           (functionp (nth 1 item)))
                  (push (car item) seen)
                  (push (list (car item)) out)))
              (nreverse out)))
           (labels (dp-window-utility--generate-window-labels
                    (length scope-wins) dp-window-keys
                    (or valid-splits 'none)))
           (win-to-label (cl-mapcar #'cons scope-wins labels))
           (descs
            (delete-dups
             (mapcar
              (lambda (w)
                (if-let* ((lbl (cdr (assq w win-to-label))))
                    (format "[%s]" lbl)
                  (format "frame %s"
                          (or (frame-parameter (window-frame w) 'name) "frame"))))
              windows))))
      (if (= (length descs) 1)
          (let ((d (car descs)))
            (cond
             ((string-prefix-p "[" d)
              (format "window %s displays the buffer" d))
             ((= (length windows) 1)
              (format "window in %s displays the buffer" d))
             (t
              (format "windows in %s display the buffer" d))))
        (format "windows %s display the buffer"
                (mapconcat #'identity descs ", "))))))

(defun dp-action--build-header-info
    (primary-phrase caller-fns alist &optional window-facts include-inhibit-same)
  "Build the `:header-info' plist for the dispatch prompt menu header.
PRIMARY-PHRASE and CALLER-FNS form caller intent info, ALIST supplies
non-caller source-labeled entries (including `inhibit-same-window' when
INCLUDE-INHIBIT-SAME is non-nil), and WINDOW-FACTS lists layout facts."
  (let ((caller-str (dp-action--format-caller-intent-info
                     primary-phrase caller-fns alist))
        (src-list (dp-action--format-source-entries
                   alist include-inhibit-same caller-fns))
        (facts (delq nil window-facts)))
    (list :caller-intent caller-str
          :source-entries src-list
          :window-facts facts)))

;;; Display execution helpers and failure-after-choice handling

(defun dp-action--apply-selection (chosen answering)
  "Apply `disbuf-pivot-action-select' to CHOSEN window and ANSWERING window."
  (pcase dp-action-select
    ('t (when (window-live-p chosen) (select-window chosen)))
    ('nil (dp-window-utility-select-window-post-command answering))))

(defun dp-action--display-in-window (buffer win type alist &optional reuse-matches)
  "Display BUFFER in WIN with `window--display-buffer' TYPE and ALIST.
Honors `(reuse-indirect . buffer)' no-swap semantics when WIN is in
REUSE-MATCHES and raises WIN's frame unless `inhibit-switch-frame'.
When `window--display-buffer' returns `nil', report with `message' and
return `fail'."
  (let* ((disp-buf
          (if (and (eq type 'reuse)
                   (eq (alist-get 'reuse-indirect alist) 'buffer)
                   (not (eq (window-buffer win) buffer))
                   reuse-matches
                   (memq win reuse-matches)
                   (window-indirect-buffer-p win buffer))
              (window-buffer win)
            buffer))
         (shown (window--display-buffer disp-buf win type alist)))
    (if shown
        (progn
          (unless (alist-get 'inhibit-switch-frame alist)
            (window--maybe-raise-frame (window-frame win)))
          shown)
      (message "disbuf-pivot: display primitive returned nil")
      'fail)))

(defun dp-action--run-caller-intent (buffer alist &optional fallback-fns)
  "Run caller's function list for BUFFER with ALIST under recursion guard.
Any FALLBACK-FNS are tried if the caller's function list is empty or
returns `nil'.  Return the first non-nil result, or `nil' if every
function returns `nil'.  Errors propagate."
  (let ((dp-window-utility--in-prompt t)
        (fns (append (dp-action--functions dp-action--action)
                     fallback-fns)))
    (cl-some (lambda (fn) (funcall fn buffer alist)) fns)))

(defun dp-action--prompt-and-display (buffer alist &rest opts)
  "Run the dispatch prompt and execute the user's choice for BUFFER and ALIST.
OPTS is a plist supporting:
- `:header-info' -- plist passed to the dispatch prompt menu header.
- `:default' -- default spec (`(:window WIN)', `(:action SYM)', string).
- `:caller-action' -- optional `(:label STR :action SYM)' spec.
- `:fallback-fns' -- action functions used by `caller-intent' when the
  caller's function list is empty (for `inhibit-same-window' intent).
- `:reuse-window' -- cross-frame window for `:action reuse-other-frame'.
- `:reuse-matches' -- matching reuse windows for `reuse-indirect' check.
- `:initial-feedback' -- optional echo-area feedback shown on entry."
  (let* ((answering (selected-window))
         (header-info (plist-get opts :header-info))
         (default-spec (plist-get opts :default))
         (caller-action (plist-get opts :caller-action))
         (fallback-fns (plist-get opts :fallback-fns))
         (reuse-win (plist-get opts :reuse-window))
         (reuse-matches (plist-get opts :reuse-matches))
         (sources (dp-action--alist-entry-sources alist))
         (feedback (plist-get opts :initial-feedback))
         (done nil)
         (outcome nil))
    (while (not done)
      (let* ((fb feedback)
             (res (progn
                    (setq feedback nil)
                    (dp-window-utility-dispatch-prompt
                     buffer alist
                     :caller-action caller-action
                     :default default-spec
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
                 (let ((shown (dp-action--display-in-window
                               buffer win 'reuse disp-alist reuse-matches)))
                   (when (windowp shown)
                     (dp-action--apply-selection shown answering))
                   (setq outcome shown
                         done t))
               (when (equal default-spec (list :window win))
                 (setq default-spec nil))
               (setq feedback
                     "disbuf-pivot: chosen window is no longer live")
               (message "%s" feedback))))
          ('split
           (let ((win (plist-get res :window))
                 (eff (plist-get res :alist)))
             (if (window-live-p win)
                 (let ((shown (dp-action--display-in-window
                               buffer win 'window eff)))
                   (when (windowp shown)
                     (dp-action--apply-selection shown answering))
                   (setq outcome shown
                         done t))
               (setq feedback
                     "disbuf-pivot: chosen window is no longer live")
               (message "%s" feedback))))
          ('reuse-other-frame
           (let ((eff (plist-get res :alist)))
             (if (window-live-p reuse-win)
                 (let ((shown (dp-action--display-in-window
                               buffer reuse-win 'reuse eff reuse-matches)))
                   (when (windowp shown)
                     (dp-action--apply-selection shown answering))
                   (setq outcome shown
                         done t))
               (setq caller-action nil
                     default-spec nil
                     feedback "disbuf-pivot: reuse window is no longer live")
               (message "%s" feedback))))
          ((or 'caller-intent 'full-frame)
           (let ((caller-res (dp-action--run-caller-intent
                              buffer (plist-get res :alist) fallback-fns)))
             (if caller-res
                 (progn
                   (when (windowp caller-res)
                     (dp-action--apply-selection caller-res answering))
                   (setq outcome caller-res
                         done t))
               (setq feedback
                     "disbuf-pivot: caller's action functions returned nil")
               (message "%s" feedback))))
          ('leave-undisplayed
           (setq outcome 'fail
                 done t))
          ('bypass
           (when dp-action--in-run
             (throw 'dp-action--bypass nil))
           (setq outcome nil
                 done t))
          (_
           (setq outcome nil
                 done t)))))
    outcome))

;;; Regulated reuse, same-window, and no-preference `dp-action--run'

(defun dp-action--handle-reuse-match
    (buffer alist preferred matches primary-phrase caller-fns
            &optional allow-indirect)
  "Handle found reuse PREFERRED window for BUFFER and ALIST.
MATCHES is the full list of reusable windows; `disbuf-pivot-reuse'
chooses automatic reuse or the dispatch prompt.  PRIMARY-PHRASE and
CALLER-FNS format header info when asking.  When ALLOW-INDIRECT is
non-nil, forward MATCHES so `(reuse-indirect . buffer)' no-swap
semantics apply (used by `display-buffer-reuse-window', not
`display-buffer-reuse-mode-window')."
  (let ((indirect-matches (when allow-indirect matches)))
    (if (eq dp-reuse 'auto)
        (dp-action--display-in-window
         buffer preferred 'reuse alist indirect-matches)
      (let* ((same-frame (eq (window-frame preferred) (selected-frame)))
             (eligible-in-scope
              (and same-frame
                   (dp-window-utility-eligible-p preferred buffer)))
             (frame-name (or (frame-parameter (window-frame preferred) 'name)
                             "frame"))
             (caller-action
              (cond
               ((not same-frame)
                (list :label (format "Reuse in frame %s" frame-name)
                      :action 'reuse-other-frame))
               ((not eligible-in-scope)
                (list :label (format "Reuse window %s"
                                     (buffer-name (window-buffer preferred)))
                      :action 'reuse-other-frame))
               (caller-fns
                '(:label "Use caller intent" :action caller-intent))))
             (default-spec (if eligible-in-scope
                               (list :window preferred)
                             '(:action reuse-other-frame)))
             (fact (dp-action--format-window-list-fact matches))
             (header (dp-action--build-header-info
                      primary-phrase caller-fns alist (list fact) t)))
        (dp-action--prompt-and-display
         buffer alist
         :header-info header
         :default default-spec
         :caller-action caller-action
         :reuse-window preferred
         :reuse-matches indirect-matches)))))

(defun dp-action--regulated-reuse-window (buffer alist)
  "Regulated replacement for `display-buffer-reuse-window' on BUFFER and ALIST."
  (when-let* ((found (dp-action--find-reuse-windows buffer alist)))
    (dp-action--handle-reuse-match
     buffer alist (car found) (cdr found)
     "no preference" (dp-action--functions dp-action--action) t)))

(defun dp-action--regulated-same-window (buffer alist)
  "Regulated replacement for `display-buffer-same-window' on BUFFER and ALIST."
  (let ((win (selected-window)))
    (when (and (not (alist-get 'inhibit-same-window alist))
               (dp-window-utility-displayable-p win buffer))
      (dp-action--display-in-window buffer win 'reuse alist))))

(defun dp-action--run (buffer alist)
  "Display BUFFER by the functions `disbuf-pivot-action-functions' lists.
`display-buffer-reuse-window' and `display-buffer-same-window' are
dispatched through the package's regulated handlers.  ALIST is passed to
each function.  Return the first non-nil result, or `nil'."
  (let ((functions (ensure-list dp-action-functions))
        (dp-action--in-run t))
    (catch 'dp-action--bypass
      (cl-some (lambda (function)
                 (pcase function
                   ('display-buffer-reuse-window
                    (dp-action--regulated-reuse-window buffer alist))
                   ('display-buffer-same-window
                    (dp-action--regulated-same-window buffer alist))
                   (_ (funcall function buffer alist))))
               functions))))

;;; Tab and frame prompts

(defun dp-action--target (alist)
  "Return `tab', `frame', or nil for ALIST and `disbuf-pivot-action--action'.
Mirrors `disbuf-pivot-action--dispatch-by-functions': respects leading
fixed-place or uncovered functions, checks tab or frame functions after
any leading reuse or spent `display-buffer-no-window' functions, and
consults `(window--pop-up-frames alist)', `tab-name', and `tab-group'
only when no effective caller function remains."
  (let ((remaining (dp-action--functions dp-action--action))
        (allow-no-window (alist-get 'allow-no-window alist))
        (target 'undecided))
    (while (and remaining (eq target 'undecided))
      (let ((fn (car remaining))
            (rest (cdr remaining)))
        (cond
         ((or (memq fn dp-action--respect-functions)
              (not (memq fn dp-action--covered-functions)))
          (setq target nil))
         ((eq fn 'display-buffer-no-window)
          (if allow-no-window
              (setq target nil)
            (setq remaining rest)))
         ((memq fn dp-action--reuse-functions)
          (if rest
              (setq remaining rest)
            (setq target nil)))
         ((memq fn dp-action--tab-functions)
          (setq target 'tab))
         ((memq fn dp-action--frame-functions)
          (setq target 'frame))
         (t
          (setq target nil)))))
    (if (not (eq target 'undecided))
        target
      (cond
       ((window--pop-up-frames alist) 'frame)
       ((or (alist-get 'tab-name alist)
            (alist-get 'tab-group alist))
        'tab)))))

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

(defun dp-action--read-and-select-tab (buffer alist &optional frame)
  "Read a tab name for BUFFER and ALIST and select or make that tab.
If a chosen existing tab vanishes before selection, re-prompt with the
tab prompt.  When FRAME is non-nil and dies while prompting, return
`frame-gone'.  Otherwise return `reuse' or `tab'."
  (let ((explicit-tab-name (alist-get 'tab-name alist))
        (result nil))
    (while (null result)
      (let* ((before-cands (unless explicit-tab-name
                             (dp-tab-bar--get-candidates)))
             (name (let ((dp-window-utility--in-prompt t))
                     (dp-action--read-tab-name buffer alist))))
        (if (and frame (framep frame) (not (frame-live-p frame)))
            (setq result 'frame-gone)
          (let* ((was-existing (and before-cands
                                    (nth 1 (assoc-string name before-cands))))
                 (still-present
                  (or (not was-existing)
                      (nth 1 (assoc-string name
                                           (dp-tab-bar--get-candidates))))))
            (if (not still-present)
                (message "disbuf-pivot: chosen tab is no longer present")
              (setq result
                    (let ((dp-window-utility--in-prompt t))
                      (dp-tab-bar-select-tab buffer alist name))))))))
    result))

(defun dp-action--display-in-tab (buffer alist &optional display-type)
  "Display BUFFER in the selected tab, reusing a window or prompting.
A window of the selected frame that already displays BUFFER is used
first, unless ALIST's `inhibit-same-window' names the selected window.
Otherwise run the dispatch prompt via
`disbuf-pivot-window-utility-choose-tab-window' and display BUFFER in
the chosen or newly split window.  DISPLAY-TYPE is the
`window--display-buffer' type for direct display (defaults to `reuse',
or `tab' when a new tab was just made).  Return `(WINDOW . TYPE)',
`(fail . fail)' when left undisplayed or a primitive returns nil,
`(frame-gone . nil)' if the target frame died, or `nil' on bypass or in
a cannot-prompt context."
  (let* ((base-type (or display-type 'reuse))
         (orig-frame (selected-frame))
         (window (get-buffer-window buffer orig-frame))
         (inhibit-same (alist-get 'inhibit-same-window alist)))
    (if (and window
             (not (and inhibit-same (eq window (selected-window)))))
        (let ((shown (dp-action--display-in-window
                      buffer window base-type alist)))
          (if (eq shown 'fail)
              (cons 'fail 'fail)
            (cons shown base-type)))
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
                 (cond
                  ((not (frame-live-p orig-frame))
                   (message "disbuf-pivot: chosen frame is no longer live")
                   (setq outcome '(frame-gone . nil)
                         done t))
                  ((window-live-p win)
                   (let ((shown (dp-action--display-in-window
                                 buffer win base-type disp-alist)))
                     (if (eq shown 'fail)
                         (setq outcome (cons 'fail 'fail)
                               done t)
                       (dp-action--apply-selection shown answering)
                       (setq outcome (cons shown base-type)
                             done t))))
                  (t
                   (setq feedback
                         "disbuf-pivot: chosen window is no longer live")
                   (message "%s" feedback)))))
              ('split
               (let ((win (plist-get res :window))
                     (eff (plist-get res :alist)))
                 (cond
                  ((not (frame-live-p orig-frame))
                   (message "disbuf-pivot: chosen frame is no longer live")
                   (setq outcome '(frame-gone . nil)
                         done t))
                  ((window-live-p win)
                   (let ((shown (dp-action--display-in-window
                                 buffer win 'window eff)))
                     (if (eq shown 'fail)
                         (setq outcome (cons 'fail 'fail)
                               done t)
                       (dp-action--apply-selection shown answering)
                       (setq outcome (cons shown 'window)
                             done t))))
                  (t
                   (setq feedback
                         "disbuf-pivot: chosen window is no longer live")
                   (message "%s" feedback)))))
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
If a chosen existing tab vanishes before selection, re-prompt with the
tab prompt.  In the tab, reuse a window that already displays BUFFER; if
there is none, run the dispatch prompt.  ALIST is the action alist of
the display.  Return `(WINDOW . TYPE)' (`reuse' for an existing tab,
`tab' for a new one, or `fail' when left undisplayed), or `nil' in a
cannot-prompt context."
  (unless (dp-window-utility-cannot-prompt-p)
    (let* ((reusable (and (alist-get 'reusable-frames alist)
                          (tab-bar-get-buffer-tab
                           buffer
                           (alist-get 'reusable-frames alist)
                           (alist-get 'ignore-current-tab alist))))
           (reusable-frame (and reusable (alist-get 'frame reusable)))
           (reusable-index (and reusable (alist-get 'index reusable)))
           (reusable-live
            (and reusable
                 (or (null reusable-frame)
                     (not (framep reusable-frame))
                     (frame-live-p reusable-frame))
                 (or (null reusable-index)
                     (< reusable-index
                        (length (tab-bar-tabs
                                 (and (framep reusable-frame)
                                      reusable-frame))))))))
      (if reusable-live
          (progn
            (let ((dp-window-utility--in-prompt t))
              (when (and reusable-frame (frame-live-p reusable-frame))
                (if (alist-get 'inhibit-switch-frame alist)
                    (select-frame reusable-frame)
                  (select-frame-set-input-focus reusable-frame)))
              (when reusable-index
                (tab-bar-select-tab (1+ reusable-index))))
            (let ((res (dp-action--display-in-tab buffer alist 'reuse)))
              (if (eq (car-safe res) 'frame-gone)
                  (cons 'fail 'fail)
                res)))
        (let* ((type (dp-action--read-and-select-tab buffer alist))
               (result (dp-action--display-in-tab
                        buffer alist
                        (if (eq type 'tab) 'tab 'reuse))))
          (when result
            (if (eq (car result) 'frame-gone)
                (cons 'fail 'fail)
              result)))))))

(defun dp-action--frames (alist)
  "Return the live visible frames the frame prompt can offer.
A `frame-predicate' entry in ALIST filters them, as it does for
`display-buffer-use-some-frame'.  A child frame is not offered: it is a
pop-up frame, not a frame the user chooses for a buffer."
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
the default name.  If a chosen existing frame vanishes before display,
re-prompt with the frame prompt.  Selecting a frame gives it focus
unless `inhibit-switch-frame'.  Read a tab name when `tab-bar-mode' is
active or the frame has more than one tab, and select or make that tab.
Then reuse a window of the tab that already displays BUFFER, or run the
dispatch prompt.  ALIST is passed to the action functions.  Return the
window, `fail', or `nil' in a cannot-prompt context."
  (unless (dp-window-utility-cannot-prompt-p)
    (let ((done nil)
          (outcome nil))
      (while (not done)
        (let* ((frames (dp-action--frames alist))
               (candidates (dp-action--frame-candidates frames))
               (names (mapcar #'car candidates))
               (name (let ((dp-window-utility--in-prompt t))
                       (completing-read
                        "Frame (empty or a new name for a new frame): "
                        names nil nil)))
               (frame (cdr (assoc-string name candidates))))
          (cond
           ((and frame (framep frame) (not (frame-live-p frame)))
            (message "disbuf-pivot: chosen frame is no longer live"))
           (frame
            (let ((tab-type nil))
              (let ((dp-window-utility--in-prompt t))
                (if (alist-get 'inhibit-switch-frame alist)
                    (select-frame frame)
                  (select-frame-set-input-focus frame))
                (when (dp-action--ask-tab-p)
                  (setq tab-type
                        (dp-action--read-and-select-tab buffer alist frame))))
              (cond
               ((or (eq tab-type 'frame-gone)
                    (and (framep frame) (not (frame-live-p frame))))
                (message "disbuf-pivot: chosen frame is no longer live"))
               (t
                (let ((result (dp-action--display-in-tab
                               buffer alist
                               (if (eq tab-type 'tab) 'tab 'reuse))))
                  (unless (eq (car-safe result) 'frame-gone)
                    (setq outcome (and result (car result))
                          done t)))))))
           (t
            (let ((dp-window-utility--in-prompt t))
              (let ((window (display-buffer-pop-up-frame buffer alist)))
                (when (and window (not (string-empty-p name)))
                  (set-frame-parameter (window-frame window) 'name name))
                (setq outcome (or window
                                  (progn
                                    (message
                                     "disbuf-pivot: display-buffer-pop-up-frame returned nil")
                                    'fail))
                      done t)))))))
      outcome)))

;;; Effective-intent classifier and dispatch (Sections 3, 4, 9)

(defun dp-action-choose-window (buffer alist)
  "Display BUFFER via the synchronous dispatch prompt for no-preference calls.
Runs `disbuf-pivot-window-utility-dispatch-prompt' for BUFFER and ALIST
with no-preference header info and window facts.  A chosen window
displays BUFFER with `window--display-buffer' type `reuse' (binding
`inhibit-same-window' to `nil' if the selected window is chosen); a
split action displays BUFFER in the new window with type `window'.
\"Use caller intent\" runs the caller's function list under the
recursion guard; \"Leave undisplayed\" returns `fail'; \"Bypass pivot\"
returns `nil'.  `disbuf-pivot-action-select' controls post-choice window
selection."
  (let* ((answering (selected-window))
         (caller-fns (dp-action--functions dp-action--action))
         (caller-action (when caller-fns
                          '(:label "Use caller intent" :action caller-intent)))
         (reuse (dp-action--find-reuse-windows buffer alist))
         (facts (delq nil
                      (list (when reuse
                              (dp-action--format-window-list-fact (cdr reuse)))
                            (when (dp-window-utility-cannot-display-p
                                   answering buffer)
                              "selected window cannot display"))))
         (header (dp-action--build-header-info
                  "no preference" caller-fns alist facts)))
    (dp-action--prompt-and-display
     buffer alist
     :header-info header
     :caller-action caller-action
     :reuse-matches (cdr-safe reuse))))

(defun dp-action--handle-same-window (buffer alist caller-fns &optional primary-phrase)
  "Handle `display-buffer-same-window' intent for BUFFER, ALIST, CALLER-FNS.
PRIMARY-PHRASE defaults to `\"same window\"' when omitted."
  (let* ((win (selected-window))
         (displayable (dp-window-utility-displayable-p win buffer))
         (inhibit-same (alist-get 'inhibit-same-window alist))
         (phrase (or primary-phrase "same window"))
         (caller-action '(:label "Use caller intent" :action caller-intent)))
    (cond
     ;; Clean same-window: selected displayable and not inhibited.
     ((and displayable (not inhibit-same))
      (dp-action--display-in-window buffer win 'reuse alist))
     ;; Conflict: same-window + inhibit-same-window.
     (inhibit-same
      (let* ((src (dp-action--alist-entry-source 'inhibit-same-window alist))
             (conflict-msg
              (if src
                  (format "disbuf-pivot: same-window conflict (%s: inhibit same window)"
                          src)
                "disbuf-pivot: same-window conflict (caller: inhibit same window)")))
        (message "%s" conflict-msg)
        (cond
         ((and displayable (eq dp-same-window-conflict 'same-window))
          (dp-action--display-in-window
           buffer win 'reuse (cons '(inhibit-same-window . nil) alist)))
         (displayable
          (let ((header (dp-action--build-header-info
                         phrase caller-fns alist nil t)))
            (dp-action--prompt-and-display
             buffer alist
             :header-info header
             :default (list :window win)
             :caller-action caller-action
             :initial-feedback conflict-msg)))
         (t
          (let ((header (dp-action--build-header-info
                         phrase caller-fns alist
                         '("selected window cannot display") t)))
            (dp-action--prompt-and-display
             buffer alist
             :header-info header
             :caller-action caller-action
             :initial-feedback conflict-msg))))))
     ;; Selected window undisplayable, no inhibit-same-window.
     (t
      (let ((header (dp-action--build-header-info
                     phrase caller-fns alist
                     '("selected window cannot display"))))
        (dp-action--prompt-and-display
         buffer alist
         :header-info header
         :caller-action caller-action))))))

(defun dp-action--handle-previous-window (buffer alist caller-fns &optional primary-phrase)
  "Handle `display-buffer-in-previous-window' for BUFFER, ALIST, CALLER-FNS.
PRIMARY-PHRASE overrides the primary intent phrase when reached via a
fallback chain."
  (let* ((prev (dp-action--find-previous-windows buffer alist))
         (phrase (or primary-phrase
                     (dp-action--function-effect-phrase
                      'display-buffer-in-previous-window
                      (cdr-safe dp-action--action)))))
    (if prev
        (let* ((preferred (plist-get prev :preferred))
               (same-frame (eq (window-frame preferred) (selected-frame)))
               (eligible-in-scope
                (and same-frame
                     (dp-window-utility-eligible-p preferred buffer)))
               (frame-name (or (frame-parameter (window-frame preferred) 'name)
                               "frame"))
               (caller-action
                (cond
                 ((not same-frame)
                  (list :label (format "Reuse in frame %s" frame-name)
                        :action 'reuse-other-frame))
                 ((not eligible-in-scope)
                  (list :label (format "Reuse window %s"
                                       (buffer-name (window-buffer preferred)))
                        :action 'reuse-other-frame))
                 (t '(:label "Use caller intent" :action caller-intent))))
               (default-spec (if eligible-in-scope
                                 (list :window preferred)
                               '(:action reuse-other-frame)))
               (header (dp-action--build-header-info
                        phrase caller-fns alist nil t)))
          (dp-action--prompt-and-display
           buffer alist
           :header-info header
           :default default-spec
           :caller-action caller-action
           :reuse-window preferred))
      ;; No previous window is usable: consult disbuf-pivot-reuse if visible.
      (if-let* ((reuse (dp-action--find-reuse-windows buffer alist)))
          (dp-action--handle-reuse-match
           buffer alist (car reuse) (cdr reuse) phrase caller-fns t)
        (let ((header (dp-action--build-header-info
                       phrase caller-fns alist nil t)))
          (dp-action--prompt-and-display
           buffer alist
           :header-info header
           :default '(:action caller-intent)
           :caller-action '(:label "Use caller intent"
                            :action caller-intent)))))))

(defun dp-action--handle-other-window (buffer alist)
  "Handle empty-function `inhibit-same-window' intent for BUFFER and ALIST."
  (let* ((reuse (dp-action--find-reuse-windows buffer alist))
         (preferred (car-safe reuse))
         (matches (cdr-safe reuse))
         (same-frame (and preferred
                          (eq (window-frame preferred) (selected-frame))))
         (eligible-in-scope
          (and same-frame
               (dp-window-utility-eligible-p preferred buffer)))
         (frame-name (and preferred
                          (or (frame-parameter (window-frame preferred) 'name)
                              "frame")))
         (caller-action
          (cond
           ((and preferred (not same-frame))
            (list :label (format "Reuse in frame %s" frame-name)
                  :action 'reuse-other-frame))
           ((and preferred (not eligible-in-scope))
            (list :label (format "Reuse window %s"
                                 (buffer-name (window-buffer preferred)))
                  :action 'reuse-other-frame))
           (t '(:label "Use caller intent" :action caller-intent))))
         (default-spec
          (cond
           (eligible-in-scope (list :window preferred))
           (preferred '(:action reuse-other-frame))
           (t '(:action caller-intent))))
         (facts (when matches
                  (list (dp-action--format-window-list-fact matches))))
         (header (dp-action--build-header-info
                  "other window" nil alist facts t)))
    (dp-action--prompt-and-display
     buffer alist
     :header-info header
     :default default-spec
     :caller-action caller-action
     :fallback-fns '(display-buffer-reuse-window
                     display-buffer-pop-up-window
                     display-buffer-in-previous-window
                     display-buffer-use-some-window
                     display-buffer-pop-up-frame)
     :reuse-window preferred
     :reuse-matches matches)))

(defun dp-action--dispatch-by-functions (buffer alist remaining full-fns)
  "Classify and dispatch BUFFER with ALIST along REMAINING caller functions.
FULL-FNS is the caller's complete function list, preserved for caller
intent info and `Use caller intent'."
  (if (null remaining)
      ;; Section 3 step 4: empty caller function list.
      (cond
       ((window--pop-up-frames alist)
        (dp-action--frame buffer alist))
       ((or (alist-get 'tab-name alist)
            (alist-get 'tab-group alist))
        (car-safe (dp-action-tab buffer alist)))
       ((alist-get 'inhibit-same-window alist)
        (dp-action--handle-other-window buffer alist))
       (t
        (dp-action--run buffer alist)))
    (let* ((fn (car remaining))
           (rest (cdr remaining))
           (primary-phrase (dp-action--function-effect-phrase
                            (car full-fns) (cdr-safe dp-action--action))))
      (cond
       ;; Fixed place or uncovered function -> Respect (return nil).
       ((or (memq fn dp-action--respect-functions)
            (not (memq fn dp-action--covered-functions)))
        nil)
       ;; No display: return `fail' when allow-no-window is non-nil; else continue.
       ((eq fn 'display-buffer-no-window)
        (if (alist-get 'allow-no-window alist)
            'fail
          (if rest
              (dp-action--dispatch-by-functions buffer alist rest full-fns)
            (let ((dp-action--action
                   (and dp-action--action
                        (cons nil (cdr-safe dp-action--action)))))
              (dp-action--dispatch-by-functions buffer alist nil nil)))))
       ;; Reuse-first chains (`display-buffer-reuse-window' / `reuse-mode-window').
       ((memq fn dp-action--reuse-functions)
        (let* ((exact-reuse (eq fn 'display-buffer-reuse-window))
               (found (if exact-reuse
                          (dp-action--find-reuse-windows buffer alist)
                        (dp-action--find-reuse-mode-windows buffer alist))))
          (cond
           (found
            (dp-action--handle-reuse-match
             buffer alist (car found) (cdr found) primary-phrase full-fns
             exact-reuse))
           (rest
            (dp-action--dispatch-by-functions buffer alist rest full-fns))
           (t
            (let ((header (dp-action--build-header-info
                           primary-phrase full-fns alist
                           '("no window displays the buffer") t)))
              (dp-action--prompt-and-display
               buffer alist
               :header-info header
               :caller-action '(:label "Use caller intent"
                                :action caller-intent)))))))
       ;; Tab intent.
       ((memq fn dp-action--tab-functions)
        (car-safe (dp-action-tab buffer alist)))
       ;; Frame intent.
       ((memq fn dp-action--frame-functions)
        (dp-action--frame buffer alist))
       ;; Same-window intent.
       ((eq fn 'display-buffer-same-window)
        (dp-action--handle-same-window buffer alist full-fns primary-phrase))
       ;; Previous-window strategy.
       ((eq fn 'display-buffer-in-previous-window)
        (dp-action--handle-previous-window buffer alist full-fns primary-phrase))
       ;; Full-frame strategy.
       ((eq fn 'display-buffer-full-frame)
        (let ((header (dp-action--build-header-info
                       primary-phrase full-fns alist nil t)))
          (dp-action--prompt-and-display
           buffer alist
           :header-info header
           :default '(:action full-frame)
           :caller-action '(:label "Display full frame"
                            :action full-frame))))
       ;; Relative placement and remaining strategies (pop-up-window,
       ;; use-some-window, use-least-recent-window, in-direction,
       ;; below-selected, at-bottom).
       (t
        (let* ((include-inhibit
                (or (eq fn 'display-buffer-use-some-window)
                    (cl-some (lambda (f) (memq f dp-action--reuse-functions))
                             full-fns)))
               (header (dp-action--build-header-info
                        primary-phrase full-fns alist nil include-inhibit)))
          (dp-action--prompt-and-display
           buffer alist
           :header-info header
           :default '(:action caller-intent)
           :caller-action '(:label "Use caller intent"
                            :action caller-intent))))))))

(defun dp-action--display (buffer alist)
  "Display BUFFER by the mode's effective-intent rules.
Return `nil' in a cannot-prompt context or for respected/uncovered
action functions.  Otherwise resolve the effective intent from
the active `display-buffer' call frame and ALIST, and dispatch per
`docs/DESIGN_RULESET.md' sections 3 and 4."
  (unless (dp-window-utility-cannot-prompt-p)
    (let* ((dp-action--extra-action 'capture)
           (dp-action--action (dp-action--current-action))
           (dp-action--extra-action (if (eq dp-action--extra-action 'capture)
                                        nil
                                      dp-action--extra-action))
           (caller-fns (dp-action--functions dp-action--action)))
      (dp-action--dispatch-by-functions buffer alist caller-fns caller-fns))))

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
  "Regulate `display-buffer' calls with explicit user control at the pivot.
When enabled, cons a `display-buffer-alist' entry at the front of the
list, matching every non-excluded buffer an earlier entry does not take;
see `disbuf-pivot-exclude-conditions'.  Priority is list order: a pop-up
window manager's rule takes precedence for its buffers when that
manager's mode is enabled after this one, since its entry is then consed
above.  Fixed-place (`display-buffer-in-side-window',
`display-buffer-in-atom-window', `display-buffer-in-child-frame') and
uncovered action functions return `nil' so Emacs runs later action
functions; regulated intents reuse, display in a displayable selected
window, run the tab or frame prompt, or open the synchronous dispatch
prompt with header info, window labels, split actions, and
window-setting toggles.  `display-buffer-overriding-action' is consulted
before the entry.  When disabled, remove that entry."
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
