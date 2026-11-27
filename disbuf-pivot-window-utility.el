;;; disbuf-pivot-window-utility.el --- Window predicates, labeling, and dispatch prompt  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/disbuf-pivot
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; The window predicates (displayable, eligible, and splittable), the
;; cannot-prompt context guards, the package's own window-labeling
;; overlays and split primitives, the synchronous dispatch prompt menu
;; (direct `display-buffer-in-side-window' rendering, responsive logical
;; column wrapping, standard Emacs other-window scrolling without moving
;; focus, small-frame echo-area fallback, split-target read, and
;; window-setting toggles with `(KEY . nil)' shadowing), and post-command
;; selection.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defconst dp-window-utility--default-window-keys
  '(?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9)
  "Default decimal digit key characters for window labels.")

(defconst dp-window-utility--window-setting-specs
  '((dedicated          ?1 "new windows only")
    (window-parameters  ?2 "any chosen window")
    (preserve-size      ?3 "new windows only")
    (window-height      ?4 "new windows only")
    (window-width       ?5 "new windows only")
    (window-size        ?6 "new frame"))
  "Fixed order, Meta-digit key, and applicability of window-setting entries.")

(defconst dp-window-utility--menu-buffer-name " *disbuf-pivot-menu*"
  "Internal buffer name used for the dispatch prompt menu.")

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
character or modified key event, FUNCTION splits the selected window and
returns the newly made window, and DESCRIPTION is shown in the dispatch
action group."
  :type '(repeat (list (choice (character :tag "Key")
                               (integer :tag "Modifier key event"))
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

;; Declared here so `disbuf-pivot-window-utility.el' has no circular
;; dependency on `disbuf-pivot.el' when checking `disbuf-pivot-header-info'.
(defvar dp-header-info)

;;; Window predicates and cannot-prompt guards

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
passes EXCLUDED-WINDOW; effective intent never makes a displayable
window ineligible."
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

(defun dp-window-utility-unsplittable-reason (window)
  "Return why WINDOW is unsplittable, or `nil' if splittable."
  (cond
   ((not (window-live-p window))
    "window is no longer live")
   ((window-minibuffer-p window)
    "minibuffer window")
   ((window-parameter window 'window-side)
    "side window")
   ((frame-parameter (window-frame window) 'unsplittable)
    "unsplittable frame")))

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

;;; Window label generation and key collision resolution

(defun dp-window-utility--scope-windows (&optional frame)
  "Return live non-minibuffer windows in the window label scope of FRAME.
When `tab-bar-mode' is active, `window-list' returns the selected tab's
windows; otherwise it returns the selected frame's windows.  Ordering
starts from `frame-first-window'."
  (let ((target-frame (or frame (selected-frame))))
    (window-list target-frame 'no-minibuf (frame-first-window target-frame))))

(defun dp-window-utility--valid-split-key-p (key)
  "Return non-nil if KEY is a valid single-key event for a split action.
Excludes `C-g', `C-M-g', `DEL', and `ESC' so abort, prefix-cancel, and
Meta prefix bindings cannot be broken."
  (and (integerp key)
       (>= key 0)
       (eventp key)
       (not (memq key '(?\C-g ?\M-\C-g ?\177 ?\e)))))

(defun dp-window-utility--usable-window-keys (window-keys split-actions)
  "Filter WINDOW-KEYS to unique valid characters not used in SPLIT-ACTIONS.
Control-g, `DEL', and `ESC' are always excluded so abort, prefix-cancel,
and Meta prefix bindings cannot be broken."
  (let ((split-keys (delq nil (mapcar #'car-safe split-actions)))
        (seen nil)
        (result nil))
    (dolist (key window-keys)
      (when (and (characterp key)
                 (not (memq key '(?\C-g ?\177 ?\e)))
                 (not (memq key split-keys))
                 (not (memq key seen)))
        (push key seen)
        (push key result)))
    (nreverse result)))

(defun dp-window-utility--encode-base-k (index keys width)
  "Encode non-negative integer INDEX into WIDTH characters from KEYS."
  (let* ((base (length keys))
         (chars nil)
         (n index))
    (dotimes (_ width)
      (push (nth (% n base) keys) chars)
      (setq n (/ n base)))
    (apply #'string chars)))

(defun dp-window-utility--generate-window-labels
    (count &optional window-keys split-actions)
  "Generate COUNT uniform fixed-width window label strings.
WINDOW-KEYS defaults to `disbuf-pivot-window-keys' and SPLIT-ACTIONS
defaults to `disbuf-pivot-split-actions'.  Keys taken by SPLIT-ACTIONS
are skipped and duplicates are removed in order.

For standard decimal digit lists (`1'-`9' or `0'-`9'), overflow uses
zero-padded decimal counting (`01'..`99', `001'..`999').  For any other
key list, overflow uses uniform fixed-width combinations strictly from
the usable keys.  When fewer than 2 usable keys remain for more than 1
window (or 0 for 1 or more windows), warn and fall back to default
digits `1'-`9' (or non-colliding letters if split keys use all digits)."
  (when (> count 0)
    (let* ((raw-keys (or window-keys dp-window-keys))
           (splits (if (eq split-actions 'none) nil
                     (or split-actions dp-split-actions)))
           (split-keys (delq nil (mapcar #'car-safe splits)))
           (usable (dp-window-utility--usable-window-keys raw-keys splits)))
      (when (or (null usable)
                (and (> count 1) (< (length usable) 2)))
        (message
         "disbuf-pivot: too few usable window keys; falling back to digits 1-9")
        (setq usable (dp-window-utility--usable-window-keys
                      dp-window-utility--default-window-keys splits))
        (when (or (null usable)
                  (and (> count 1) (< (length usable) 2)))
          (setq usable (dp-window-utility--usable-window-keys
                        (number-sequence ?a ?z) splits)))
        (when (or (null usable)
                  (and (> count 1) (< (length usable) 2)))
          (setq usable dp-window-utility--default-window-keys)))
      (cond
       ;; 1-based decimal counting: 1..9, then 01..99, then 001..999.
       ((and (equal usable dp-window-utility--default-window-keys)
             (not (memq ?0 split-keys)))
        (let* ((width (if (<= count 9) 1 (length (number-to-string count))))
               (fmt (format "%%0%dd" width)))
          (cl-loop for i from 1 to count
                   collect (format fmt i))))
       ;; 0-based decimal counting: 0..9, then 00..99, ...
       ((equal usable '(?0 ?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9))
        (let* ((width (if (<= count 10)
                          1
                        (length (number-to-string (1- count)))))
               (fmt (format "%%0%dd" width)))
          (cl-loop for i from 0 below count
                   collect (format fmt i))))
       ;; General uniform fixed-width base-K combinations from usable keys.
       (t
        (let ((base (length usable))
              (width 1)
              (cap (length usable)))
          (while (< cap count)
            (setq width (1+ width)
                  cap (* cap base)))
          (cl-loop for i from 0 below count
                   collect (dp-window-utility--encode-base-k
                            i usable width))))))))

(defun dp-window-utility--meta-event (char)
  "Return the single Emacs key event for Meta combined with CHAR."
  (aref (kbd (format "M-%c" char)) 0))

(defun dp-window-utility--ctrl-meta-event (char)
  "Return the single Emacs key event for Control-Meta combined with CHAR."
  (aref (kbd (format "C-M-%c" char)) 0))

(defun dp-window-utility--key-label (event)
  "Return a concise display string for key EVENT or key vector."
  (key-description (if (vectorp event) event (vector event))))

(defun dp-window-utility--allocate-key (kind preferred-char used-events)
  "Allocate a free key event of KIND (`letter' or `digit') not in USED-EVENTS.
PREFERRED-CHAR is tried first as a Meta key.  If taken, tries remaining
Meta keys of the same KIND (preferring spare digits `7'-`9' for `digit'
and skipping `v' during `letter' fallback so `M-v' remains unused), then
falls back to `C-M-' keys of the same KIND."
  (let* ((meta-candidates
          (pcase kind
            ('letter
             (append (list preferred-char)
                     (cl-remove-if (lambda (c) (memq c (list preferred-char ?v)))
                                   (number-sequence ?a ?z))
                     (unless (eq preferred-char ?v) (list ?v))))
            ('digit
             (append (list preferred-char)
                     (cl-remove preferred-char '(?7 ?8 ?9 ?0 ?1 ?2 ?3 ?4 ?5 ?6))))))
         (cm-candidates
          (pcase kind
            ('letter
             (append (unless (eq preferred-char ?g) (list preferred-char))
                     (cl-remove-if (lambda (c) (memq c (list preferred-char ?g ?v)))
                                   (number-sequence ?a ?z))
                     (unless (eq preferred-char ?v) (list ?v))))
            ('digit
             (append (list preferred-char)
                     (cl-remove preferred-char '(?7 ?8 ?9 ?0 ?1 ?2 ?3 ?4 ?5 ?6))))))
         (all-events
          (append (mapcar #'dp-window-utility--meta-event meta-candidates)
                  (mapcar #'dp-window-utility--ctrl-meta-event cm-candidates))))
    (cl-find-if-not (lambda (ev) (memq ev used-events)) all-events)))

;;; Window-setting toggles and `(KEY . nil)' shadowing

(defun dp-window-utility--init-toggles (alist &optional sources)
  "Build toggle state records for window-setting entries present in ALIST.
Entries appear in the fixed order of
`disbuf-pivot-window-utility--window-setting-specs'.  SOURCES is an
optional alist mapping entry key symbols to source labels (such as
\"base action\")."
  (let ((toggles nil))
    (dolist (spec dp-window-utility--window-setting-specs)
      (cl-destructuring-bind (key digit applicability) spec
        (let* ((cell (assq key alist))
               (val (cdr cell)))
          (when (and cell val
                     (not (and (eq key 'preserve-size)
                               (equal val '(nil . nil)))))
            (push (list :key key
                        :digit digit
                        :applicability applicability
                        :source (cdr (assq key sources))
                        :enabled t)
                  toggles)))))
    (nreverse toggles)))

(defun dp-window-utility--toggles-all-state (toggles)
  "Return `on', `off', or `mixed' for TOGGLES."
  (let ((any-on nil)
        (any-off nil))
    (dolist (tog toggles)
      (if (plist-get tog :enabled)
          (setq any-on t)
        (setq any-off t)))
    (cond ((and any-on any-off) 'mixed)
          (any-on 'on)
          (t 'off))))

(defun dp-window-utility--toggle-entry (toggles key)
  "Flip the enabled state of window-setting entry KEY in TOGGLES."
  (when-let* ((tog (cl-find key toggles :key (lambda (x) (plist-get x :key)))))
    (plist-put tog :enabled (not (plist-get tog :enabled)))))

(defun dp-window-utility--toggle-all (toggles)
  "Toggle all entries in TOGGLES at once.
When any entry is on, turn all off; when all are off, turn all on."
  (let ((new-state (eq (dp-window-utility--toggles-all-state toggles) 'off)))
    (dolist (tog toggles)
      (plist-put tog :enabled new-state))))

(defun dp-window-utility--effective-alist (base-alist toggles)
  "Return a local copy of BASE-ALIST shadowing disabled TOGGLES with nil.
Disabled entries are prepended as `(KEY . nil)' so later associations
and Emacs fallbacks (such as `display-buffer-mark-dedicated' or
`display-buffer-in-direction' default `window-height') are shadowed
without mutating BASE-ALIST."
  (let ((shadows nil))
    (dolist (tog toggles)
      (unless (plist-get tog :enabled)
        (push (cons (plist-get tog :key) nil) shadows)))
    (if shadows
        (append (nreverse shadows) base-alist)
      base-alist)))

;;; Window-label overlays

(defun dp-window-utility--overlay-position (win)
  "Return `(POS . PAD)' for placing a visible window-label overlay in WIN.
Skips leading invisible text at `window-start' within the visible window
range and offsets for horizontal scrolling (`window-hscroll') so the
window label remains visible at the top-left of WIN."
  (let* ((buf (window-buffer win))
         (hscroll (window-hscroll win))
         (vis-col (if (> hscroll 0)
                      (+ hscroll
                         (if (display-graphic-p (window-frame win)) 0 1))
                    0)))
    (with-current-buffer buf
      (save-excursion
        (let* ((start (max (point-min)
                           (min (point-max) (window-start win))))
               (limit (min (point-max)
                           (or (window-end win) (point-max))))
               (pos start))
          (while (and (< pos limit) (invisible-p pos))
            (setq pos (next-single-char-property-change
                       pos 'invisible nil limit)))
          (when (and (>= pos limit) (> limit start) (invisible-p pos))
            (setq pos start))
          (goto-char pos)
          (let ((pad 0))
            (when (> vis-col 0)
              (let ((eol (line-end-position)))
                (move-to-column vis-col)
                (when (> (point) eol)
                  (goto-char eol))
                (setq pos (point))
                (let ((col (current-column)))
                  (when (< col vis-col)
                    (setq pad (- vis-col col)))))
              (while (and (< pos limit) (invisible-p pos))
                (setq pos (next-single-char-property-change
                           pos 'invisible nil limit)
                      pad 0)))
            (cons pos pad)))))))

(defun dp-window-utility--create-overlays (window-entries &optional split-mode)
  "Create window-label overlays for WINDOW-ENTRIES.
When SPLIT-MODE is non-nil, highlight splittable windows with
`disbuf-pivot-eligible-label' and unsplittable windows with
`disbuf-pivot-ineligible-label'; otherwise highlight eligible windows."
  (let ((overlays nil))
    (dolist (entry window-entries)
      (let ((win (plist-get entry :window)))
        (when (window-live-p win)
          (let* ((buf (window-buffer win))
                 (pos-pad (dp-window-utility--overlay-position win))
                 (pos (car pos-pad))
                 (pad (cdr pos-pad))
                 (label (plist-get entry :label))
                 (face (if (if split-mode
                               (plist-get entry :splittable)
                             (plist-get entry :eligible))
                           'dp-eligible-label
                         'dp-ineligible-label))
                 (text (concat (when (> pad 0) (make-string pad ?\s))
                               (propertize (format "[%s]" label) 'face face)))
                 (ov (make-overlay pos pos buf)))
            (overlay-put ov 'window win)
            (overlay-put ov 'priority 1000)
            (overlay-put ov 'before-string text)
            (push ov overlays)))))
    (nreverse overlays)))

(defun dp-window-utility--delete-overlays (overlays)
  "Delete every overlay in OVERLAYS."
  (dolist (ov overlays)
    (when (overlayp ov)
      (delete-overlay ov))))

;;; Menu rendering, logical hanging-indent wrapping, and layout

(defun dp-window-utility--sanitize-line (text)
  "Replace newlines, carriage returns, and tabs in TEXT with spaces."
  (if (string-match-p "[\r\n\t]" text)
      (replace-regexp-in-string "[\r\n\t]+" " " text t t)
    text))

(defun dp-window-utility--truncate-to-width (str max-width)
  "Return prefix of STR fitting within MAX-WIDTH display columns.
Preserves text properties and returns `(PREFIX . REST)'."
  (let ((len (length str))
        (i 0)
        (w 0))
    (while (and (< i len)
                (<= (+ w (char-width (aref str i))) max-width))
      (setq w (+ w (char-width (aref str i)))
            i (1+ i)))
    (when (and (= i 0) (> len 0))
      (setq i 1))
    (cons (substring str 0 i) (substring str i))))

(defun dp-window-utility--wrap-line (text width &optional hanging-indent)
  "Wrap propertized string TEXT logically to WIDTH display columns.
Continuation lines are indented by HANGING-INDENT spaces (clamped so at
least 4 columns remain for text when WIDTH permits).  Returns a
non-empty list of strings."
  (let* ((w (max 1 width))
         (indent (min (or hanging-indent 0) (max 0 (- w 4))))
         (indent-str (make-string indent ?\s))
         (lines nil)
         (rest (dp-window-utility--sanitize-line text))
         (first t))
    (if (<= (string-width rest) w)
        (list rest)
      (while (or first (> (length rest) 0))
        (let* ((avail (if first w (- w indent)))
               (cur-prefix (if first "" indent-str)))
          (setq first nil)
          (if (<= (string-width rest) avail)
              (progn
                (push (concat cur-prefix rest) lines)
                (setq rest ""))
            (let* ((split (dp-window-utility--truncate-to-width rest avail))
                   (head (car split))
                   (tail (cdr split))
                   (tail-at-boundary
                    (and (> (length tail) 0) (eq (aref tail 0) ?\s)))
                   ;; Prefer breaking at the last space after non-space text,
                   ;; unless TAIL already begins at a word boundary.
                   (space-pos (unless tail-at-boundary
                                (cl-position ?\s head :from-end t))))
              (if (and space-pos
                       (> space-pos 0)
                       (string-match-p "[^[:space:]]"
                                       (substring head 0 space-pos)))
                  (let* ((piece (string-trim-right (substring head 0 space-pos)))
                         (after (concat (substring head (1+ space-pos)) tail)))
                    (push (concat cur-prefix piece) lines)
                    (setq rest (string-trim-left after)))
                (let ((piece (if (string-match-p "[^[:space:]]" head)
                                 (string-trim-right head)
                               head)))
                  (push (concat cur-prefix piece) lines))
                (setq rest (string-trim-left tail)))))))
      (nreverse lines))))

(defun dp-window-utility--detect-hanging-indent (line)
  "Compute a natural hanging indent for menu LINE."
  (cond
   ((string-match "\\`\\([[:space:]]*\\[[^]]+\\][[:space:]]+\\)" line)
    (string-width (match-string 1 line)))
   ((string-match "\\`\\([[:alpha:]][^:]*:[[:space:]]+\\)" line)
    (string-width (match-string 1 line)))
   ((string-match "\\`\\([[:space:]]+\\)" line)
    (+ (string-width (match-string 1 line)) 2))
   (t 2)))

(defun dp-window-utility--header-part-enabled-p (part)
  "Return non-nil if header info PART is enabled by `disbuf-pivot-header-info'."
  (let ((opt (if (boundp 'dp-header-info) dp-header-info t)))
    (cond ((eq opt t) t)
          ((null opt) nil)
          ((listp opt) (memq part opt))
          (t t))))

(defun dp-window-utility--format-header (width header-info default-desc)
  "Format the dispatch prompt menu header lines wrapped to WIDTH.
HEADER-INFO is a plist with optional `:caller-intent', `:source-entries',
and `:window-facts'.  DEFAULT-DESC is the dispatch prompt default string
and is always shown when non-nil regardless of `disbuf-pivot-header-info'."
  (let ((raw-lines nil))
    (when (dp-window-utility--header-part-enabled-p 'caller-intent)
      (when-let* ((caller (plist-get header-info :caller-intent)))
        (unless (string-empty-p caller)
          (push caller raw-lines))))
    (when (dp-window-utility--header-part-enabled-p 'source-entries)
      (dolist (src (plist-get header-info :source-entries))
        (when (and (stringp src) (not (string-empty-p src)))
          (push src raw-lines))))
    (when (dp-window-utility--header-part-enabled-p 'window-facts)
      (dolist (fact (plist-get header-info :window-facts))
        (when (and (stringp fact) (not (string-empty-p fact)))
          (push fact raw-lines))))
    (when (and (stringp default-desc) (not (string-empty-p default-desc)))
      (push (concat (propertize "Default: " 'face 'bold) default-desc)
            raw-lines))
    (let ((wrapped nil))
      (dolist (line (nreverse raw-lines))
        (setq wrapped
              (nconc wrapped
                     (dp-window-utility--wrap-line
                      line width
                      (dp-window-utility--detect-hanging-indent line)))))
      wrapped)))

(defun dp-window-utility--build-groups
    (window-entries split-entries caller-entry leave-entry bypass-entry
                    toggles toggle-all-key &optional split-mode)
  "Build the dispatch prompt menu groups as a list of line lists.
WINDOW-ENTRIES populates the Windows group; SPLIT-ENTRIES, CALLER-ENTRY,
LEAVE-ENTRY, and BYPASS-ENTRY populate the Dispatch actions group;
TOGGLES and TOGGLE-ALL-KEY populate the optional Window settings group
when TOGGLES is non-nil.  When SPLIT-MODE is non-nil, highlight Windows
group labels by `:splittable' instead of `:eligible'."
  (let ((win-lines (list (propertize "Windows" 'face 'bold)))
        (act-lines (list (propertize "Dispatch actions" 'face 'bold)))
        (set-lines nil))
    ;; Group 1: Windows
    (dolist (entry window-entries)
      (let* ((label (plist-get entry :label))
             (buf-name (dp-window-utility--sanitize-line
                        (plist-get entry :buffer-name)))
             (face (if (if split-mode
                           (plist-get entry :splittable)
                         (plist-get entry :eligible))
                       'dp-eligible-label
                     'dp-ineligible-label)))
        (push (concat (propertize (format "[%s]" label) 'face face)
                      " " buf-name)
              win-lines)))
    ;; Group 2: Dispatch actions
    (when split-entries
      (push (propertize "Split" 'face 'italic) act-lines)
      (dolist (sp split-entries)
        (push (format "  [%s] %s"
                      (propertize (plist-get sp :key-label)
                                  'face 'dp-eligible-label)
                      (plist-get sp :description))
              act-lines)))
    (when caller-entry
      (push (propertize "Caller intent" 'face 'italic) act-lines)
      (push (format "  [%s] %s"
                    (propertize (plist-get caller-entry :key-label)
                                'face 'dp-eligible-label)
                    (plist-get caller-entry :label))
            act-lines))
    (push (propertize "Other" 'face 'italic) act-lines)
    (when leave-entry
      (push (format "  [%s] %s"
                    (propertize (plist-get leave-entry :key-label)
                                'face 'dp-eligible-label)
                    (plist-get leave-entry :label))
            act-lines))
    (when bypass-entry
      (push (format "  [%s] %s"
                    (propertize (plist-get bypass-entry :key-label)
                                'face 'dp-eligible-label)
                    (plist-get bypass-entry :label))
            act-lines))
    ;; Group 3: Window settings (shown when >= 1 entry is present)
    (when toggles
      (push (propertize "Window settings" 'face 'bold) set-lines)
      (let ((all-state (dp-window-utility--toggles-all-state toggles)))
        (push (format "[%s] All (%s)"
                      (propertize (dp-window-utility--key-label toggle-all-key)
                                  'face 'dp-eligible-label)
                      all-state)
              set-lines))
      (dolist (tog toggles)
        (let* ((state (if (plist-get tog :enabled) "on" "off"))
               (app (plist-get tog :applicability))
               (src (plist-get tog :source))
               (detail (if src
                           (format "%s, %s; %s" state app src)
                         (format "%s, %s" state app))))
          (push (format "[%s] %s (%s)"
                        (propertize (plist-get tog :key-label)
                                    'face 'dp-eligible-label)
                        (plist-get tog :key)
                        detail)
                set-lines))))
    (let ((groups (list (nreverse win-lines) (nreverse act-lines))))
      (if set-lines
          (append groups (list (nreverse set-lines)))
        groups))))

(defun dp-window-utility--distribute-widths (groups total-width min-col)
  "Distribute TOTAL-WIDTH across GROUPS, each getting at least MIN-COL."
  (let* ((n (length groups))
         (natural (mapcar (lambda (lines)
                            (max min-col
                                 (cl-reduce #'max lines
                                            :key #'string-width
                                            :initial-value min-col)))
                          groups))
         (sum-nat (apply #'+ natural)))
    (if (<= sum-nat total-width)
        ;; Every group fits naturally; give leftover space to the last column.
        (let ((extra (- total-width sum-nat))
              (result (copy-sequence natural)))
          (setf (nth (1- n) result) (+ (nth (1- n) result) extra))
          result)
      ;; Distribute extra space above (* n min-col) proportionally to excess.
      (let* ((pool (- total-width (* n min-col)))
             (excess (mapcar (lambda (w) (max 0 (- w min-col))) natural))
             (sum-exc (apply #'+ excess))
             (widths
              (if (zerop sum-exc)
                  (make-list n (/ total-width n))
                (mapcar (lambda (e) (+ min-col (/ (* pool e) sum-exc)))
                        excess)))
             (rem (- total-width (apply #'+ widths))))
        (when (> rem 0)
          (setf (nth (1- n) widths) (+ (nth (1- n) widths) rem)))
        widths))))

(defun dp-window-utility--zip-columns (groups widths)
  "Wrap each group in GROUPS to its width in WIDTHS and zip side by side."
  (let* ((wrapped-cols
          (cl-mapcar
           (lambda (lines col-w)
             (let ((out nil))
               (dolist (line lines)
                 (setq out
                       (nconc out
                              (dp-window-utility--wrap-line
                               line col-w
                               (dp-window-utility--detect-hanging-indent line)))))
               out))
           groups widths))
         (max-rows (cl-reduce #'max wrapped-cols
                              :key #'length
                              :initial-value 0))
         (rows nil))
    (dotimes (r max-rows)
      (let ((cells nil))
        (cl-mapc
         (lambda (col col-w)
           (let* ((cell (or (nth r col) ""))
                  (pad (max 0 (- col-w (string-width cell)))))
             (push (concat cell (make-string pad ?\s)) cells)))
         wrapped-cols widths)
        (push (string-trim-right (mapconcat #'identity (nreverse cells) " | "))
              rows)))
    (nreverse rows)))

(defun dp-window-utility--layout-groups (groups avail-width min-col)
  "Lay out GROUPS responsively into 3, 2, or 1 columns within AVAIL-WIDTH.
Return a list of rendered lines, or `nil' when AVAIL-WIDTH < MIN-COL."
  (when (>= avail-width min-col)
    (let ((g (length groups)))
      (cond
       ;; All groups side by side (3 cols for 3 groups, or 2 cols for 2 groups).
       ((>= avail-width (+ (* g min-col) (* (1- g) 3)))
        (let* ((inner (- avail-width (* (1- g) 3)))
               (widths (dp-window-utility--distribute-widths
                        groups inner min-col)))
          (dp-window-utility--zip-columns groups widths)))
       ;; 3 groups in 2-column layout: Windows | Dispatch actions, then settings.
       ((and (= g 3) (>= avail-width (+ (* 2 min-col) 3)))
        (let* ((top-groups (list (nth 0 groups) (nth 1 groups)))
               (top-widths (dp-window-utility--distribute-widths
                            top-groups (- avail-width 3) min-col))
               (top-rows (dp-window-utility--zip-columns top-groups top-widths))
               (bot-rows (dp-window-utility--zip-columns
                          (list (nth 2 groups)) (list avail-width))))
          (append top-rows (list (make-string avail-width ?-)) bot-rows)))
       ;; 1 stacked column.
       (t
        (let ((out nil))
          (dotimes (i g)
            (when (> i 0)
              (setq out (nconc out (list ""))))
            (setq out
                  (nconc out
                         (dp-window-utility--zip-columns
                          (list (nth i groups)) (list avail-width)))))
          out))))))

(defun dp-window-utility--render-menu-lines
    (avail-width header-info default-desc groups &optional split-banner)
  "Render complete dispatch prompt menu lines for AVAIL-WIDTH.
HEADER-INFO, DEFAULT-DESC, and optional SPLIT-BANNER form the header;
GROUPS supplies the dispatch prompt menu groups.  Return a list of
lines, or `nil' if AVAIL-WIDTH is below
`disbuf-pivot-menu-min-column-width'."
  (when (>= avail-width dp-menu-min-column-width)
    (let* ((header (if split-banner
                       (dp-window-utility--wrap-line
                        (propertize split-banner 'face 'bold) avail-width 2)
                     (dp-window-utility--format-header
                      avail-width header-info default-desc)))
           (body (dp-window-utility--layout-groups
                  groups avail-width dp-menu-min-column-width)))
      (when body
        (if header
            (append header (list (make-string avail-width ?-)) body)
          body)))))

(defun dp-window-utility--format-echo-prompt
    (window-entries split-entries caller-entry leave-entry bypass-entry
                    toggles toggle-all-key
                    &optional prefix split-desc small-frame default-desc)
  "Build a concise echo-area prompt string for the dispatch prompt.
WINDOW-ENTRIES, SPLIT-ENTRIES, CALLER-ENTRY, LEAVE-ENTRY, BYPASS-ENTRY,
TOGGLES, and TOGGLE-ALL-KEY describe the available keys; PREFIX holds an
active multi-key prefix, SPLIT-DESC names an active split-target read,
SMALL-FRAME prefixes the small-frame fallback notice, and DEFAULT-DESC
displays the dispatch prompt default when present."
  (cond
   (split-desc
    (let* ((split-labels
            (delq nil
                  (mapcar (lambda (e)
                            (and (plist-get e :splittable)
                                 (plist-get e :label)))
                          window-entries)))
           (range (cond
                   ((null split-labels) "[]")
                   ((= (length split-labels) 1)
                    (format "[%s]" (car split-labels)))
                   ((<= (length split-labels) 6)
                    (format "[%s]" (mapconcat #'identity split-labels ", ")))
                   (t
                    (format "[%s..%s]" (car split-labels)
                            (car (last split-labels)))))))
      (if (and prefix (not (string-empty-p prefix)))
          (format "%s — window key: %s- (DEL back, C-g abort)"
                  split-desc prefix)
        (format "%s — choose window to split %s (DEL back, C-g abort): "
                split-desc range))))
   ((and prefix (not (string-empty-p prefix)))
    (format "Window key: %s- (DEL back, C-g abort)" prefix))
   (t
    (let ((parts nil))
      (when (and (stringp default-desc) (not (string-empty-p default-desc)))
        (push (format "Default: %s" (substring-no-properties default-desc))
              parts))
      (when window-entries
        (let ((first-l (plist-get (car window-entries) :label))
              (last-l (plist-get (car (last window-entries)) :label)))
          (push (if (string= first-l last-l)
                    (format "[%s] win" first-l)
                  (format "[%s..%s] win" first-l last-l))
                parts)))
      (when split-entries
        (push (format "[%s] split"
                      (mapconcat (lambda (sp) (plist-get sp :key-label))
                                 split-entries "/"))
              parts))
      (when caller-entry
        (push (format "[%s] %s"
                      (plist-get caller-entry :key-label)
                      (plist-get caller-entry :label))
              parts))
      (when leave-entry
        (push (format "[%s] leave" (plist-get leave-entry :key-label))
              parts))
      (when bypass-entry
        (push (format "[%s] bypass" (plist-get bypass-entry :key-label))
              parts))
      (when toggles
        (push (format "[%s] settings(%s) %s"
                      (dp-window-utility--key-label toggle-all-key)
                      (dp-window-utility--toggles-all-state toggles)
                      (mapconcat
                       (lambda (tog)
                         (format "[%s] %s(%s)"
                                 (plist-get tog :key-label)
                                 (plist-get tog :key)
                                 (if (plist-get tog :enabled) "on" "off")))
                       toggles " "))
              parts))
      (push "[C-g] abort" parts)
      (concat (if small-frame "Frame too small for menu — " "")
              (mapconcat #'identity (nreverse parts) ", ")
              ": ")))))

;;; Direct side-window display and scrolling

(defun dp-window-utility--next-bottom-slot (frame)
  "Return an unused bottom side-window slot number on FRAME."
  (let ((max-slot nil))
    (dolist (win (window-list frame 'no-minibuf))
      (when (eq (window-parameter win 'window-side) 'bottom)
        (let* ((raw (window-parameter win 'window-slot))
               (slot (if (numberp raw) raw 0)))
          (setq max-slot (if max-slot (max max-slot slot) slot)))))
    (if max-slot (1+ max-slot) 0)))

(defun dp-window-utility--max-side-height (frame)
  "Return maximum lines available for a bottom side window on FRAME.
When a bottom side window already exists on FRAME, a new bottom slot
splits it horizontally and shares its height; otherwise available height
is the root window's height minus its minimum vertical size."
  (if-let* ((bottom-major (window-with-parameter 'window-side 'bottom frame t)))
      (window-total-height bottom-major)
    (let* ((root (frame-root-window frame))
           (root-h (window-total-height root))
           (min-h (window-min-size root nil)))
      (max 0 (- root-h min-h)))))

(defun dp-window-utility--bottom-side-snapshots (frame)
  "Snapshot live bottom side windows on FRAME before opening a new slot."
  (let ((snaps nil))
    (dolist (win (window-list frame 'no-minibuf))
      (when (eq (window-parameter win 'window-side) 'bottom)
        (push (list win
                    (window-buffer win)
                    (window-start win)
                    (window-point win)
                    (copy-alist (window-parameters win))
                    (window-dedicated-p win)
                    (copy-tree (window-prev-buffers win))
                    (copy-tree (window-next-buffers win)))
              snaps)))
    snaps))

(defun dp-window-utility--restore-side-snapshots (snapshots)
  "Restore bottom side windows recorded in SNAPSHOTS."
  (dolist (snap snapshots)
    (cl-destructuring-bind (win buf start pt params dedicated prev next) snap
      (when (and (window-live-p win) (buffer-live-p buf))
        (set-window-dedicated-p win nil)
        (set-window-buffer win buf)
        (set-window-start win start)
        (set-window-point win pt)
        (dolist (cur (copy-alist (window-parameters win)))
          (unless (assq (car cur) params)
            (set-window-parameter win (car cur) nil)))
        (dolist (cell params)
          (set-window-parameter win (car cell) (cdr cell)))
        (set-window-dedicated-p win dedicated)
        (set-window-prev-buffers win prev)
        (set-window-next-buffers win next)))))

(defun dp-window-utility--scroll-mode-line-hint ()
  "Return the escaped mode-line hint for current `scroll-other-window' keys."
  (replace-regexp-in-string
   "%" "%%"
   (substitute-command-keys
    " Scroll: \\[scroll-other-window] / \\[scroll-other-window-down]")))

(defun dp-window-utility--populate-menu-buffer
    (buf lines scrollable &optional scroll-hint)
  "Write LINES into menu buffer BUF and configure its mode line.
When SCROLLABLE is non-nil, show SCROLL-HINT (or the active
`scroll-other-window' and `scroll-other-window-down' bindings via
`substitute-command-keys') in the mode line; otherwise hide the mode
line."
  (with-current-buffer buf
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert (mapconcat #'identity lines "\n"))
      (goto-char (point-min)))
    (setq-local truncate-lines t)
    (setq-local cursor-type nil)
    (setq-local buffer-read-only t)
    (setq-local header-line-format nil)
    (setq-local tab-line-format nil)
    (setq-local display-line-numbers nil)
    (setq-local show-trailing-whitespace nil)
    (setq-local display-fill-column-indicator nil)
    (setq-local mode-line-format
                (when scrollable
                  (list (or scroll-hint
                            (dp-window-utility--scroll-mode-line-hint))
                        "  (%p)")))))

(defun dp-window-utility--usable-window-width (win)
  "Return usable display columns in WIN without triggering TTY `$' truncation."
  (let ((w (window-body-width win)))
    (if (display-graphic-p (window-frame win))
        w
      (max 1 (1- w)))))

(defun dp-window-utility--open-menu-window
    (menu-buf frame header-info default-desc groups
              &optional split-banner scroll-hint)
  "Open the dispatch prompt menu side window for MENU-BUF on FRAME.
HEADER-INFO, DEFAULT-DESC, GROUPS, optional SPLIT-BANNER, and optional
SCROLL-HINT supply the menu content.  Uses
`display-buffer-in-side-window' directly (never `display-buffer').
Returns the created menu window, or `nil' when FRAME is unsplittable,
below `disbuf-pivot-menu-min-column-width' or
`disbuf-pivot-menu-min-height', or when the side window cannot be
created on FRAME without clobbering existing side windows."
  (unless (frame-parameter frame 'unsplittable)
    (let* ((frame-w (window-total-width (frame-root-window frame)))
           (bottom-major (window-with-parameter 'window-side 'bottom frame t))
           (max-h (dp-window-utility--max-side-height frame))
           (can-split-bottom
            (or (null bottom-major)
                (>= (- (window-total-width bottom-major)
                       (window-min-size bottom-major t))
                    (max window-min-width dp-menu-min-column-width)))))
      (when (and can-split-bottom
                 (>= frame-w dp-menu-min-column-width)
                 (>= max-h dp-menu-min-height))
        (let* ((init-lines (dp-window-utility--render-menu-lines
                            frame-w header-info default-desc groups split-banner))
               (pre-wins (window-list frame 'no-minibuf))
               (snapshots (when bottom-major
                            (dp-window-utility--bottom-side-snapshots frame)))
               (slot (dp-window-utility--next-bottom-slot frame))
               (root-h (window-total-height (frame-root-window frame)))
               (cap-h (min max-h (max dp-menu-min-height
                                      (floor (* 0.65 root-h))))))
          (when init-lines
            (let* ((needed (length init-lines))
                   (scrollable (> needed cap-h))
                   (target-h (if scrollable
                                 (min max-h (1+ cap-h))
                               (min cap-h needed))))
              (dp-window-utility--populate-menu-buffer
               menu-buf init-lines scrollable scroll-hint)
              (let* ((window-sides-slots nil)
                     (dp-window-utility--in-prompt t)
                     (win (condition-case nil
                              (with-selected-frame frame
                                (display-buffer-in-side-window
                                 menu-buf
                                 `((side . bottom)
                                   (slot . ,slot)
                                   (window-height . ,target-h)
                                   (window-parameters
                                    . ((no-other-window . t)
                                       (no-delete-other-windows . t))))))
                            (error nil))))
                (cond
                 ((not (and (window-live-p win)
                            (eq (window-frame win) frame)
                            (not (memq win pre-wins))))
                  (cond
                   ((and (window-live-p win) (not (memq win pre-wins)))
                    (delete-window win))
                   (snapshots
                    (dp-window-utility--restore-side-snapshots snapshots)))
                  nil)
                 (t
                  ;; Re-render if the side window is narrower than FRAME-W
                  ;; (for example when another bottom side window shares the
                  ;; edge or fringes/TTY reserve a column).
                  (let* ((actual-w (dp-window-utility--usable-window-width win))
                         (lines
                          (if (= actual-w frame-w)
                              init-lines
                            (dp-window-utility--render-menu-lines
                             actual-w header-info default-desc
                             groups split-banner))))
                    (if (or (null lines)
                            (< actual-w dp-menu-min-column-width))
                        (progn
                          (delete-window win)
                          nil)
                      (let* ((actual-needed (length lines))
                             (min-required (min dp-menu-min-height
                                                actual-needed)))
                        ;; When this is the sole bottom side window and actual
                        ;; body width changed wrapped line count, adjust height.
                        (when (and (null bottom-major)
                                   (/= actual-needed needed))
                          (let* ((want-scroll (> actual-needed cap-h))
                                 (desired-h (if want-scroll
                                                (min max-h (1+ cap-h))
                                              (min cap-h actual-needed)))
                                 (delta (- desired-h (window-total-height win))))
                            (unless (zerop delta)
                              (ignore-errors
                                (window-resize win delta nil nil t)))))
                        (let* ((avail-no-ml
                                (+ (window-body-height win)
                                   (if (buffer-local-value 'mode-line-format
                                                           menu-buf)
                                       1
                                     0)))
                               (now-scrollable (> actual-needed avail-no-ml)))
                          (dp-window-utility--populate-menu-buffer
                           menu-buf lines now-scrollable scroll-hint)
                          (if (< (window-total-height win) min-required)
                              (progn
                                (delete-window win)
                                nil)
                            (window-preserve-size win nil t)
                            win)))))))))))))))

(defun dp-window-utility--refresh-menu-window
    (menu-win menu-buf header-info default-desc groups
              &optional split-banner scroll-hint scroll-line)
  "Re-render MENU-BUF in live MENU-WIN while preserving scroll alignment.
HEADER-INFO, DEFAULT-DESC, GROUPS, optional SPLIT-BANNER, and optional
SCROLL-HINT supply the menu content.  When SCROLL-LINE is `top', reset
scroll to line 1; when it is a positive integer, restore to that line;
when `nil', preserve the current top visible line number so text-length
changes (such as `on' to `mixed') never leave `window-start' mid-line."
  (when (window-live-p menu-win)
    (let* ((saved-line
            (cond
             ((eq scroll-line 'top) 1)
             ((and (integerp scroll-line) (> scroll-line 0)) scroll-line)
             (t (with-current-buffer menu-buf
                  (line-number-at-pos
                   (min (max (point-min) (window-start menu-win))
                        (point-max)))))))
           (width (dp-window-utility--usable-window-width menu-win))
           (lines (dp-window-utility--render-menu-lines
                   width header-info default-desc groups split-banner)))
      (when lines
        (let* ((avail-no-ml
                (+ (window-body-height menu-win)
                   (if (buffer-local-value 'mode-line-format menu-buf) 1 0)))
               (scrollable (> (length lines) avail-no-ml)))
          (dp-window-utility--populate-menu-buffer
           menu-buf lines scrollable scroll-hint)
          (let ((target-pos
                 (with-current-buffer menu-buf
                   (if (and scrollable (> saved-line 1))
                       (progn
                         (goto-char (point-min))
                         (forward-line (1- saved-line))
                         (line-beginning-position))
                     (point-min)))))
            (set-window-start menu-win target-pos)
            (set-window-point menu-win target-pos)))))))

(defun dp-window-utility--scroll-menu (menu-win direction)
  "Scroll MENU-WIN in DIRECTION (`up' forward, `down' backward, or wheel).
Leaves `selected-window' unchanged."
  (when (window-live-p menu-win)
    (with-selected-window menu-win
      (ignore-errors
        (pcase direction
          ('up (scroll-up-command))
          ('down (scroll-down-command))
          ('wheel-up (scroll-down 3))
          ('wheel-down (scroll-up 3)))))))

;;; Synchronous key reading and dispatch prompt loop

(defun dp-window-utility--abort-key-p (key-vec binding)
  "Return non-nil if KEY-VEC / BINDING represents a `C-g' or `C-M-g' abort."
  (or (eq binding 'abort)
      (and (or (null binding) (numberp binding))
           (vectorp key-vec)
           (> (length key-vec) 0)
           (memq (aref key-vec (1- (length key-vec))) '(?\C-g ?\M-\C-g)))))

(defun dp-window-utility--allocate-keys-batch (kind preferred-chars used-events)
  "Allocate keys of KIND for PREFERRED-CHARS against USED-EVENTS in two passes.
Pass 1 assigns every free preferred Meta key so colliding entries cannot
steal another present entry's preferred key.  Pass 2 assigns fallback
keys for entries whose preferred key was taken.  Returns a cons
`(ALLOCATED-LIST . NEW-USED-EVENTS)'."
  (let* ((used (copy-sequence used-events))
         (result (make-list (length preferred-chars) nil)))
    ;; Pass 1: assign free preferred Meta keys first.
    (cl-loop for ch in preferred-chars
             for idx from 0
             for pref = (dp-window-utility--meta-event ch)
             unless (memq pref used)
             do (push pref used)
                (setf (nth idx result) pref))
    ;; Pass 2: resolve colliding entries.
    (cl-loop for ch in preferred-chars
             for idx from 0
             unless (nth idx result)
             do (let ((ev (dp-window-utility--allocate-key kind ch used)))
                  (push ev used)
                  (setf (nth idx result) ev)))
    (cons result used)))

(defun dp-window-utility--scroll-key-bindings ()
  "Capture current user key sequences for `scroll-other-window' commands.
Returns a cons `(FORWARD-KEYS . BACKWARD-KEYS)' for
`scroll-other-window' and `scroll-other-window-down'."
  (cons (where-is-internal 'scroll-other-window)
        (where-is-internal 'scroll-other-window-down)))

(defun dp-window-utility--key-seq-free-p (keymap seq)
  "Return non-nil if SEQ can be bound in KEYMAP without clobbering bindings."
  (let ((existing (lookup-key keymap seq)))
    (or (null existing)
        (and (numberp existing)
             (null (lookup-key keymap (cl-subseq seq 0 existing)))))))

(defun dp-window-utility--bind-scroll-keys (keymap scroll-bindings used-events)
  "Bind SCROLL-BINDINGS into KEYMAP without overriding USED-EVENTS."
  (dolist (pair (list (cons (car scroll-bindings) '(scroll . up))
                      (cons (cdr scroll-bindings) '(scroll . down))))
    (dolist (raw-seq (car pair))
      (let ((seq (and (or (vectorp raw-seq) (stringp raw-seq))
                      (vconcat raw-seq))))
        (when (and seq (> (length seq) 0)
                   (not (memq (aref seq 0)
                              '(menu-bar tool-bar tab-bar header-line
                                mode-line remap ?\C-g ?\M-\C-g)))
                   (not (memq (aref seq (1- (length seq)))
                              '(?\C-g ?\M-\C-g)))
                   (not (memq (aref seq 0) used-events))
                   (dp-window-utility--key-seq-free-p keymap seq))
          (ignore-errors (define-key keymap seq (cdr pair)))))))
  (dolist (ev '((wheel-down . wheel-down)
                (wheel-up   . wheel-up)
                (mouse-5    . wheel-down)
                (mouse-4    . wheel-up)))
    (let ((action (cons 'mouse-scroll (cdr ev))))
      (define-key keymap (vector (car ev)) action)
      (dolist (area '(mode-line left-fringe right-fringe
                      left-margin right-margin vertical-scroll-bar))
        (define-key keymap (vector area (car ev)) action)))))

(defun dp-window-utility--build-main-keymap
    (window-entries split-entries caller-entry leave-entry bypass-entry
                    toggles toggle-all-key scroll-bindings used-events)
  "Build the `overriding-local-map' for the main dispatch prompt state.
Binds WINDOW-ENTRIES, SPLIT-ENTRIES, CALLER-ENTRY, LEAVE-ENTRY,
BYPASS-ENTRY, TOGGLES, TOGGLE-ALL-KEY, and SCROLL-BINDINGS (skipping
events in USED-EVENTS)."
  (let ((map (make-sparse-keymap)))
    ;; Window labels: exact for length-1, prefix-char for length > 1.
    (dolist (entry window-entries)
      (let ((label (plist-get entry :label)))
        (if (= (length label) 1)
            (define-key map (vector (aref label 0))
                        (cons 'window entry))
          (let ((ch (aref label 0)))
            (define-key map (vector ch) (cons 'prefix-char ch))))))
    ;; Split actions.
    (dolist (sp split-entries)
      (define-key map (vector (plist-get sp :key)) (cons 'split sp)))
    ;; Caller intent, Leave undisplayed, Bypass pivot.
    (when caller-entry
      (define-key map (vector (plist-get caller-entry :key))
                  (cons 'caller caller-entry)))
    (when leave-entry
      (define-key map (vector (plist-get leave-entry :key)) 'leave))
    (when bypass-entry
      (define-key map (vector (plist-get bypass-entry :key)) 'bypass))
    ;; Window-setting toggles.
    (when toggles
      (define-key map (vector toggle-all-key) 'toggle-all)
      (dolist (tog toggles)
        (define-key map (vector (plist-get tog :event))
                    (cons 'toggle (plist-get tog :key)))))
    (dp-window-utility--bind-scroll-keys map scroll-bindings used-events)
    ;; C-g and C-M-g always abort; bind last so no user config can shadow them.
    (define-key map (kbd "C-g") 'abort)
    (define-key map (kbd "C-M-g") 'abort)
    map))

(defun dp-window-utility--build-label-keymap
    (window-entries scroll-bindings &optional allow-cancel-prefix)
  "Build a keymap reading one character toward WINDOW-ENTRIES labels.
Also binds SCROLL-BINDINGS, and binds `DEL' to cancel or step back when
ALLOW-CANCEL-PREFIX is non-nil."
  (let ((map (make-sparse-keymap))
        (used nil))
    (dolist (entry window-entries)
      (let ((label (plist-get entry :label)))
        (dotimes (i (length label))
          (let ((ch (aref label i)))
            (push ch used)
            (define-key map (vector ch) (cons 'label-char ch))))))
    (when allow-cancel-prefix
      (push ?\177 used)
      (push 'backspace used)
      (define-key map (kbd "DEL") 'back)
      (define-key map (kbd "<backspace>") 'back))
    (dp-window-utility--bind-scroll-keys map scroll-bindings used)
    (define-key map (kbd "C-g") 'abort)
    (define-key map (kbd "C-M-g") 'abort)
    map))

(defun dp-window-utility--read-key-vector (keymap &optional prompt)
  "Read one key sequence vector using KEYMAP as `overriding-local-map'.
PROMPT is shown in the echo area when non-nil.  Disables input methods
and text conversion so dispatch prompt keys are read literally."
  (let ((overriding-local-map keymap)
        (overriding-terminal-local-map nil)
        (input-method-function nil)
        (echo-keystrokes 0))
    (read-key-sequence-vector prompt nil t nil nil t)))

(defun dp-window-utility--resolve-default-desc
    (default-spec window-entries caller-entry)
  "Format the dispatch prompt default string from DEFAULT-SPEC.
WINDOW-ENTRIES and CALLER-ENTRY resolve `:window' and `:action' specs."
  (pcase default-spec
    ((pred stringp) default-spec)
    (`(:window ,win)
     (when-let* ((entry (cl-find win window-entries
                                 :key (lambda (e) (plist-get e :window)))))
       (let ((face (if (plist-get entry :eligible)
                       'dp-eligible-label
                     'dp-ineligible-label)))
         (format "[%s] %s"
                 (propertize (plist-get entry :label) 'face face)
                 (dp-window-utility--sanitize-line
                  (plist-get entry :buffer-name))))))
    (`(:action ,act)
     (when (and caller-entry
                (or (eq act 'caller-intent)
                    (eq act (plist-get caller-entry :action))))
       (format "[%s] %s"
               (propertize (plist-get caller-entry :key-label)
                           'face 'dp-eligible-label)
               (plist-get caller-entry :label))))
    (_ nil)))

(defun dp-window-utility--handle-mouse-scroll (menu-win key-vec dir)
  "Scroll MENU-WIN in DIR for mouse wheel event KEY-VEC if applicable."
  (let* ((ev (and (vectorp key-vec)
                  (> (length key-vec) 0)
                  (aref key-vec (1- (length key-vec)))))
         (target-win (and (listp ev)
                          (ignore-errors (posn-window (event-start ev))))))
    (when (or (null target-win) (eq target-win menu-win))
      (dp-window-utility--scroll-menu menu-win dir))))

(defun dp-window-utility--read-split-target
    (split-entry window-entries menu-win menu-buf
                 header-info default-desc groups split-groups
                 scroll-bindings scroll-hint)
  "Read a splittable target window from WINDOW-ENTRIES for SPLIT-ENTRY.
Updates MENU-WIN and MENU-BUF with SPLIT-GROUPS during the read and
restores GROUPS on exit (preserving HEADER-INFO, DEFAULT-DESC,
SCROLL-BINDINGS, and SCROLL-HINT).  Returns the chosen splittable
window, or `nil' if the user presses `DEL' to return to the main
dispatch prompt.  `C-g' signals `quit'."
  (let* ((desc (plist-get split-entry :description))
         (split-banner (format "%s — choose window to split (DEL back, C-g abort)"
                               desc))
         (saved-main-line
          (when (and (window-live-p menu-win) (buffer-live-p menu-buf))
            (with-current-buffer menu-buf
              (line-number-at-pos
               (min (max (point-min) (window-start menu-win))
                    (point-max))))))
         (split-overlays (dp-window-utility--create-overlays window-entries t))
         (label-map (dp-window-utility--build-label-keymap
                     window-entries scroll-bindings t))
         (prefix "")
         (echo-feedback nil)
         (done nil)
         (chosen nil))
    (unwind-protect
        (progn
          (when (window-live-p menu-win)
            (dp-window-utility--refresh-menu-window
             menu-win menu-buf header-info default-desc
             split-groups split-banner scroll-hint 'top))
          (while (not done)
            (let* ((base-prompt (dp-window-utility--format-echo-prompt
                                 window-entries nil nil nil nil nil nil
                                 prefix desc (not (window-live-p menu-win))))
                   (prompt (if (and echo-feedback (string-empty-p prefix))
                               (let ((fb echo-feedback))
                                 (setq echo-feedback nil)
                                 (concat fb " — " base-prompt))
                             base-prompt))
                   (key-vec (dp-window-utility--read-key-vector label-map prompt))
                   (binding (lookup-key label-map key-vec)))
              (cond
               ((dp-window-utility--abort-key-p key-vec binding)
                (signal 'quit nil))
               (t
                (pcase binding
                  ('back
                   (if (> (length prefix) 0)
                       (setq prefix "")
                     (setq done t chosen nil)))
                  (`(scroll . ,dir)
                   (dp-window-utility--scroll-menu menu-win dir))
                  (`(mouse-scroll . ,dir)
                   (dp-window-utility--handle-mouse-scroll menu-win key-vec dir))
                  (`(label-char . ,ch)
                   (let* ((next (concat prefix (char-to-string ch)))
                          (exact (cl-find next window-entries
                                          :key (lambda (e) (plist-get e :label))
                                          :test #'string=))
                          (matches (cl-remove-if-not
                                    (lambda (e)
                                      (string-prefix-p next (plist-get e :label)))
                                    window-entries)))
                     (cond
                      (exact
                       (let* ((win (plist-get exact :window))
                              (reason (dp-window-utility-unsplittable-reason win)))
                         (if (null reason)
                             (setq done t chosen win)
                           (setq echo-feedback
                                 (format "disbuf-pivot: cannot split %s (%s)"
                                         (plist-get exact :buffer-name)
                                         reason))
                           (message "%s" echo-feedback)
                           (setq prefix ""))))
                      (matches
                       (setq prefix next))
                      (t
                       (setq echo-feedback
                             (format "disbuf-pivot: no window label starts with %s"
                                     next))
                       (message "%s" echo-feedback)
                       (setq prefix "")))))
                  (_
                   (setq echo-feedback
                         "disbuf-pivot: choose a window label or press DEL/C-g")
                   (message "%s" echo-feedback)
                   (setq prefix ""))))))))
      (dp-window-utility--delete-overlays split-overlays)
      (when (window-live-p menu-win)
        (dp-window-utility--refresh-menu-window
         menu-win menu-buf header-info default-desc
         groups nil scroll-hint (or saved-main-line 'top))))
    chosen))

(defun dp-window-utility--no-splittable-reason (frame window-entries)
  "Return the reason string when 0 splittable windows exist in WINDOW-ENTRIES.
FRAME is the target frame."
  (let ((live (cl-remove-if-not
               (lambda (e) (window-live-p (plist-get e :window)))
               window-entries)))
    (cond
     ((frame-parameter frame 'unsplittable) "unsplittable frame")
     ((null live) "no live windows")
     ((cl-every (lambda (e)
                  (window-parameter (plist-get e :window) 'window-side))
                live)
      "only side windows")
     (t "no live windows"))))

(defun dp-window-utility-dispatch-prompt (buffer alist &rest args)
  "Run the synchronous dispatch prompt for BUFFER and ALIST.
Returns `nil' in a cannot-prompt context.  Otherwise reads keys until a
terminal choice is made and returns a plist:

- `(:action window :window WIN :alist EFFECTIVE-ALIST)'
- `(:action split :window NEW-WIN :alist EFFECTIVE-ALIST)'
- `(:action CALLER-ACTION :alist EFFECTIVE-ALIST)'
- `(:action leave-undisplayed :alist EFFECTIVE-ALIST)'
- `(:action bypass)'

Pressing `C-g' signals `quit' without running later functions.

Supported keyword ARGS:
- `:excluded-window' -- window excluded by `disbuf-pivot-other-window-prefix'.
- `:header-info' -- plist with `:caller-intent', `:source-entries',
  `:window-facts'.
- `:default' -- default cue string, `(:window WIN)', or
  `(:action caller-intent)'.
- `:caller-action' -- optional plist `(:label STR :action SYM)'.
- `:sources' -- optional alist mapping window-setting keys to source labels.
- `:frame' -- target frame (defaults to `selected-frame').
- `:initial-feedback' -- optional echo-area feedback shown on entry."
  (unless (dp-window-utility-cannot-prompt-p)
    (let* ((excluded-window (plist-get args :excluded-window))
           (header-info (plist-get args :header-info))
           (default-spec (plist-get args :default))
           (caller-spec (plist-get args :caller-action))
           (sources (plist-get args :sources))
           (frame (or (plist-get args :frame) (selected-frame)))
           (initial-feedback (plist-get args :initial-feedback))
           ;; Capture scroll bindings and hint BEFORE overriding-local-map.
           (scroll-bindings (dp-window-utility--scroll-key-bindings))
           (scroll-hint (dp-window-utility--scroll-mode-line-hint))
           ;; Compute scope windows and labels BEFORE creating menu window.
           (scope-wins (dp-window-utility--scope-windows frame))
           (split-entries
            (let ((seen-splits nil)
                  (out nil))
              (dolist (item dp-split-actions)
                (when (and (consp item)
                           (dp-window-utility--valid-split-key-p (car item))
                           (not (memq (car item) seen-splits))
                           (functionp (nth 1 item)))
                  (push (car item) seen-splits)
                  (push (list :key (car item)
                              :key-label (dp-window-utility--key-label
                                          (car item))
                              :fn (nth 1 item)
                              :description (or (nth 2 item)
                                               (symbol-name (nth 1 item))))
                        out)))
              (nreverse out)))
           (valid-splits (mapcar (lambda (sp) (list (plist-get sp :key)))
                                 split-entries))
           (labels (dp-window-utility--generate-window-labels
                    (length scope-wins) dp-window-keys
                    (or valid-splits 'none)))
           (window-entries
            (cl-mapcar
             (lambda (win label)
               (list :window win
                     :label label
                     :buffer-name (buffer-name (window-buffer win))
                     :eligible (dp-window-utility-eligible-p
                                win buffer excluded-window)
                     :splittable (dp-window-utility-splittable-p win)))
             scope-wins labels))
           ;; Track used events: configured window first-chars and split keys win.
           (used-events
            (append (mapcar (lambda (sp) (plist-get sp :key)) split-entries)
                    (delete-dups
                     (mapcar (lambda (e) (aref (plist-get e :label) 0))
                             window-entries))))
           ;; Two-pass allocation for Meta-letter package dispatch actions.
           (letter-specs
            (append (when caller-spec (list (cons 'caller ?c)))
                    (when (alist-get 'allow-no-window alist)
                      (list (cons 'leave ?n)))
                    (list (cons 'bypass ?b))))
           (letter-alloc (dp-window-utility--allocate-keys-batch
                          'letter (mapcar #'cdr letter-specs) used-events))
           (letter-keys (car letter-alloc))
           (letter-map (cl-mapcar (lambda (spec ev) (cons (car spec) ev))
                                  letter-specs letter-keys))
           (caller-entry
            (when caller-spec
              (let ((ev (cdr (assq 'caller letter-map))))
                (list :key ev
                      :key-label (dp-window-utility--key-label ev)
                      :label (or (plist-get caller-spec :label)
                                 "Use caller intent")
                      :action (or (plist-get caller-spec :action)
                                  'caller-intent)))))
           (leave-entry
            (when (alist-get 'allow-no-window alist)
              (let ((ev (cdr (assq 'leave letter-map))))
                (list :key ev
                      :key-label (dp-window-utility--key-label ev)
                      :label "Leave undisplayed"))))
           (bypass-entry
            (let ((ev (cdr (assq 'bypass letter-map))))
              (list :key ev
                    :key-label (dp-window-utility--key-label ev)
                    :label "Bypass pivot")))
           ;; Two-pass allocation for Meta-digit window-setting toggles.
           (toggles (dp-window-utility--init-toggles alist sources))
           (digit-alloc
            (when toggles
              (dp-window-utility--allocate-keys-batch
               'digit
               (cons ?0 (mapcar (lambda (tog) (plist-get tog :digit)) toggles))
               (cdr letter-alloc))))
           (toggle-all-key (when digit-alloc (caar digit-alloc)))
           (final-used-events (if digit-alloc
                                  (cdr digit-alloc)
                                (cdr letter-alloc)))
           (default-desc
            (dp-window-utility--resolve-default-desc
             default-spec window-entries caller-entry))
           (menu-buf (get-buffer-create dp-window-utility--menu-buffer-name))
           (dp-window-utility--in-prompt t)
           overlays menu-win result)
      ;; Store allocated Meta-digit keys on each present window-setting toggle.
      (when digit-alloc
        (cl-mapc (lambda (tog ev)
                   (plist-put tog :event ev)
                   (plist-put tog :key-label (dp-window-utility--key-label ev)))
                 toggles (cdar digit-alloc)))
      (unwind-protect
          (let* ((groups (dp-window-utility--build-groups
                          window-entries split-entries caller-entry
                          leave-entry bypass-entry toggles toggle-all-key))
                 (main-map (dp-window-utility--build-main-keymap
                            window-entries split-entries caller-entry
                            leave-entry bypass-entry toggles toggle-all-key
                            scroll-bindings final-used-events))
                 (prefix-map (dp-window-utility--build-label-keymap
                              window-entries scroll-bindings t))
                 (prefix "")
                 (echo-feedback initial-feedback))
            ;; Open menu before creating overlays so shrunken windows update
            ;; their `window-start' first and overlays remain visible.
            (setq menu-win (dp-window-utility--open-menu-window
                            menu-buf frame header-info default-desc
                            groups nil scroll-hint))
            (when (window-live-p menu-win)
              (redisplay))
            (setq overlays (dp-window-utility--create-overlays window-entries))
            (while (null result)
              (let* ((in-prefix (> (length prefix) 0))
                     (small-frame (not (window-live-p menu-win)))
                     (prompt (cond
                              (in-prefix
                               (dp-window-utility--format-echo-prompt
                                window-entries split-entries caller-entry
                                leave-entry bypass-entry toggles toggle-all-key
                                prefix nil small-frame default-desc))
                              (echo-feedback
                               (let ((fb echo-feedback))
                                 (setq echo-feedback nil)
                                 (if small-frame
                                     (concat
                                      fb " — "
                                      (dp-window-utility--format-echo-prompt
                                       window-entries split-entries caller-entry
                                       leave-entry bypass-entry toggles
                                       toggle-all-key nil nil nil default-desc))
                                   fb)))
                              (small-frame
                               (dp-window-utility--format-echo-prompt
                                window-entries split-entries caller-entry
                                leave-entry bypass-entry toggles toggle-all-key
                                nil nil t default-desc))
                              (t nil)))
                     (active-map (if in-prefix prefix-map main-map))
                     (key-vec (dp-window-utility--read-key-vector
                               active-map prompt))
                     (binding (lookup-key active-map key-vec)))
                (cond
                 ((dp-window-utility--abort-key-p key-vec binding)
                  (signal 'quit nil))
                 (t
                  (pcase binding
                    ('back
                     (setq prefix ""))
                    (`(scroll . ,dir)
                     (dp-window-utility--scroll-menu menu-win dir))
                    (`(mouse-scroll . ,dir)
                     (dp-window-utility--handle-mouse-scroll
                      menu-win key-vec dir))
                    ('toggle-all
                     (dp-window-utility--toggle-all toggles)
                     (setq groups (dp-window-utility--build-groups
                                   window-entries split-entries caller-entry
                                   leave-entry bypass-entry toggles
                                   toggle-all-key))
                     (dp-window-utility--refresh-menu-window
                      menu-win menu-buf header-info default-desc
                      groups nil scroll-hint)
                     (when small-frame
                       (setq echo-feedback
                             (format "disbuf-pivot: all window settings %s"
                                     (dp-window-utility--toggles-all-state
                                      toggles)))))
                    (`(toggle . ,sym)
                     (dp-window-utility--toggle-entry toggles sym)
                     (setq groups (dp-window-utility--build-groups
                                   window-entries split-entries caller-entry
                                   leave-entry bypass-entry toggles
                                   toggle-all-key))
                     (dp-window-utility--refresh-menu-window
                      menu-win menu-buf header-info default-desc
                      groups nil scroll-hint)
                     (when small-frame
                       (let ((tog (cl-find sym toggles
                                           :key (lambda (x) (plist-get x :key)))))
                         (setq echo-feedback
                               (format "disbuf-pivot: %s %s"
                                       sym
                                       (if (plist-get tog :enabled)
                                           "on" "off"))))))
                    ('bypass
                     (setq result (list :action 'bypass)))
                    ('leave
                     (setq result
                           (list :action 'leave-undisplayed
                                 :alist (dp-window-utility--effective-alist
                                         alist toggles))))
                    (`(caller . ,centry)
                     (setq result
                           (list :action (plist-get centry :action)
                                 :alist (dp-window-utility--effective-alist
                                         alist toggles))))
                    (`(window . ,wentry)
                     (let ((win (plist-get wentry :window)))
                       (if (dp-window-utility-eligible-p
                            win buffer excluded-window)
                           (setq result
                                 (list :action 'window
                                       :window win
                                       :alist (dp-window-utility--effective-alist
                                               alist toggles)))
                         (let ((reason (dp-window-utility-ineligible-reason
                                        win buffer excluded-window)))
                           (setq echo-feedback
                                 (format
                                  "disbuf-pivot: window [%s] is ineligible (%s)"
                                  (plist-get wentry :label) reason))
                           (message "%s" echo-feedback)))))
                    ((or `(prefix-char . ,ch) `(label-char . ,ch))
                     (let* ((next (concat prefix (char-to-string ch)))
                            (exact (cl-find next window-entries
                                            :key (lambda (e) (plist-get e :label))
                                            :test #'string=))
                            (matches (cl-remove-if-not
                                      (lambda (e)
                                        (string-prefix-p
                                         next (plist-get e :label)))
                                      window-entries)))
                       (cond
                        (exact
                         (setq prefix "")
                         (let ((win (plist-get exact :window)))
                           (if (dp-window-utility-eligible-p
                                win buffer excluded-window)
                               (setq result
                                     (list :action 'window
                                           :window win
                                           :alist
                                           (dp-window-utility--effective-alist
                                            alist toggles)))
                             (let ((reason (dp-window-utility-ineligible-reason
                                            win buffer excluded-window)))
                               (setq echo-feedback
                                     (format
                                      "disbuf-pivot: window [%s] is ineligible (%s)"
                                      (plist-get exact :label) reason))
                               (message "%s" echo-feedback)))))
                        (matches
                         (setq prefix next))
                        (t
                         (setq prefix ""
                               echo-feedback
                               (format
                                "disbuf-pivot: no window label starts with %s"
                                next))
                         (message "%s" echo-feedback)))))
                    (`(split . ,sp)
                     (let* ((splittable
                             (cl-remove-if-not
                              (lambda (e)
                                (dp-window-utility-splittable-p
                                 (plist-get e :window)))
                              window-entries))
                            (count (length splittable))
                            (target-win
                             (cond
                              ((= count 0)
                               (setq echo-feedback
                                     (format
                                      "disbuf-pivot: no splittable window (%s)"
                                      (dp-window-utility--no-splittable-reason
                                       frame window-entries)))
                               (message "%s" echo-feedback)
                               nil)
                              ((= count 1)
                               (plist-get (car splittable) :window))
                              (t
                               ;; Temporarily hide main overlays during split-target read.
                               (dp-window-utility--delete-overlays overlays)
                               (setq overlays nil)
                               (let ((split-groups
                                      (dp-window-utility--build-groups
                                       window-entries split-entries caller-entry
                                       leave-entry bypass-entry toggles
                                       toggle-all-key t)))
                                 (dp-window-utility--read-split-target
                                  sp window-entries menu-win menu-buf
                                  header-info default-desc groups split-groups
                                  scroll-bindings scroll-hint))))))
                       (cond
                        (target-win
                         ;; Close menu before splitting so the split operates on
                         ;; the user's real layout geometry cleanly.
                         (dp-window-utility--delete-overlays overlays)
                         (setq overlays nil)
                         (when (window-live-p menu-win)
                           (delete-window menu-win)
                           (setq menu-win nil))
                         (condition-case err
                             (let ((new-win
                                    (with-selected-window target-win
                                      (funcall (plist-get sp :fn)))))
                               (if (window-live-p new-win)
                                   (setq result
                                         (list :action 'split
                                               :window new-win
                                               :alist
                                               (dp-window-utility--effective-alist
                                                alist toggles)))
                                 (setq echo-feedback
                                       "disbuf-pivot: split did not return a live window")
                                 (message "%s" echo-feedback)
                                 (setq menu-win
                                       (dp-window-utility--open-menu-window
                                        menu-buf frame header-info
                                        default-desc groups nil scroll-hint))
                                 (when (window-live-p menu-win) (redisplay))
                                 (setq overlays
                                       (dp-window-utility--create-overlays
                                        window-entries))))
                           (error
                            (setq echo-feedback
                                  (format "disbuf-pivot: split failed (%s)"
                                          (error-message-string err)))
                            (message "%s" echo-feedback)
                            (setq menu-win
                                  (dp-window-utility--open-menu-window
                                   menu-buf frame header-info
                                   default-desc groups nil scroll-hint))
                            (when (window-live-p menu-win) (redisplay))
                            (setq overlays
                                  (dp-window-utility--create-overlays
                                   window-entries)))))
                        ((> count 1)
                         ;; User pressed DEL to cancel split-target read.
                         (setq overlays
                               (dp-window-utility--create-overlays
                                window-entries))))))
                    (_
                     (setq prefix ""
                           echo-feedback
                           (format "disbuf-pivot: unknown dispatch prompt key %s"
                                   (dp-window-utility--key-label key-vec)))
                     (message "%s" echo-feedback))))))))
        (dp-window-utility--delete-overlays overlays)
        (when (window-live-p menu-win)
          (delete-window menu-win))
        (when (buffer-live-p menu-buf)
          (kill-buffer menu-buf)))
      result)))

;;; Post-command selection

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

;;; Legacy prefix compatibility bridge (removed in Milestone 5)

(defcustom dp-window-utility-split-maximum 4
  "Legacy split threshold consulted only by `disbuf-pivot-other-window-prefix'.
Not consulted by the redesigned core `display-buffer-alist' entry."
  :group 'windows
  :type 'integer)

(defcustom dp-window-utility-split-maximum-exclude-side t
  "Legacy option leaving side windows out of the prefix split count.
See `disbuf-pivot-window-utility-split-maximum'."
  :group 'windows
  :type 'boolean)

(defcustom dp-window-utility-split-maximum-exclude-dedicated t
  "Legacy option leaving dedicated windows out of the prefix split count.
See `disbuf-pivot-window-utility-split-maximum'."
  :group 'windows
  :type 'boolean)

(defun dp-window-utility-split-p ()
  "Return non-nil when the legacy prefix split count is below its maximum.
Not consulted by the redesigned core `display-buffer-alist' entry."
  (let ((count (cl-count-if
                (lambda (window)
                  (and (not (and dp-window-utility-split-maximum-exclude-side
                                 (window-parameter window 'window-side)))
                       (not (and dp-window-utility-split-maximum-exclude-dedicated
                                 (window-dedicated-p window)))))
                (dp-window-utility--scope-windows))))
    (< count dp-window-utility-split-maximum)))

(defun dp-window-utility-choose-display-window
    (scope ignore-current &optional _mode-line buffer alist)
  "Compatibility bridge choosing a window via the dispatch prompt.
SCOPE must be non-nil.  When IGNORE-CURRENT is non-nil, mark the
selected window ineligible.  BUFFER and ALIST are forwarded to
`disbuf-pivot-window-utility-dispatch-prompt'.  Return the chosen or
newly split window, or `nil'."
  (when (and scope (not (dp-window-utility-cannot-prompt-p)))
    (let ((res (dp-window-utility-dispatch-prompt
                buffer alist
                :excluded-window (and ignore-current (selected-window)))))
      (pcase (plist-get res :action)
        ((or 'window 'split) (plist-get res :window))
        (_ nil)))))

(defun dp-window-utility-choose-tab-window (alist &optional buffer &rest args)
  "Run the dispatch prompt for the selected frame for ALIST and BUFFER.
Optional keyword ARGS are forwarded to
`disbuf-pivot-window-utility-dispatch-prompt'.  Return a dispatch prompt
result plist or `nil' in a cannot-prompt context."
  (unless (dp-window-utility-cannot-prompt-p)
    (apply #'dp-window-utility-dispatch-prompt buffer alist args)))

(provide 'dp-window-utility)

;; Local Variables:
;; checkdoc-allow-quoting-nil-and-t: t
;; read-symbol-shorthands: (("dp-" . "disbuf-pivot-"))
;; End:

;;; disbuf-pivot-window-utility.el ends here
