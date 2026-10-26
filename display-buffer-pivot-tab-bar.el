;;; display-buffer-pivot-tab-bar.el --- Tab bar data, history and plain reader  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/display-buffer-pivot
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; The tab bar's candidates, history, sort and annotations, and a plain
;; `completing-read' reader for a tab name.  The consult integration and
;; the tab-switch overrides are in `ia-tab-bar-modified-consult' in the
;; `emacs-utils' repository.  That integration sets
;; `display-buffer-pivot-tab-bar-read-function' so the display action's
;; tab prompt uses its consult reader.

(require 'cl-lib)
(require 'tab-bar)

;; Pacify the compiler for dynamic overrides
(defvar marginalia-annotators)

;;; Code:

(defgroup display-buffer-pivot-tab-bar nil
  "Customizations for index-safe tab bar management."
  :group 'tab-bar)

(defcustom display-buffer-pivot-tab-bar-enable-history t
  "Non-nil to enable history tracking and display closed tabs as candidates."
  :type 'boolean
  :group 'display-buffer-pivot-tab-bar)

(defcustom display-buffer-pivot-tab-bar-sanitize-new-tab nil
  "Non-nil to not bring previous selected buffer window to the new tab."
  :type 'boolean
  :group 'display-buffer-pivot-tab-bar)

(defcustom display-buffer-pivot-tab-bar-disable-marginalia t
  "Non-nil to natively suppress Marginalia during tab switching."
  :type 'boolean
  :group 'display-buffer-pivot-tab-bar)

(defcustom display-buffer-pivot-tab-bar-show-extra-states nil
  "Non-nil to display the active buffer, window count, and group in completion."
  :type 'boolean
  :group 'display-buffer-pivot-tab-bar)

(defcustom display-buffer-pivot-tab-bar-rename-include-active t
  "Non-nil to include active tab names as candidates when renaming a tab."
  :type 'boolean
  :group 'display-buffer-pivot-tab-bar)

(defcustom display-buffer-pivot-tab-bar-rename-enable-history t
  "Non-nil to include closed tab history as candidates when renaming a tab."
  :type 'boolean
  :group 'display-buffer-pivot-tab-bar)

(defcustom display-buffer-pivot-tab-bar-history-limit 20
  "Maximum number of history candidates to persist for tab names."
  :type 'integer
  :group 'display-buffer-pivot-tab-bar
  :set (lambda (symbol value)
         (set-default symbol value)
         (put 'display-buffer-pivot-tab-bar--history 'history-length value)))

(defcustom display-buffer-pivot-tab-bar-sort-function #'display-buffer-pivot-tab-bar-sort-active-first
  "Function to sort completion candidates before rendering."
  :type '(choice (const :tag "Active Tabs First" display-buffer-pivot-tab-bar-sort-active-first)
                 (const :tag "Let Frontend Sort" nil)
                 (function :tag "Custom Sort Function"))
  :group 'display-buffer-pivot-tab-bar)

(defcustom display-buffer-pivot-tab-bar-read-function nil
  "Function to read a tab name, or nil to use `completing-read'.
It is called with PROMPT, CANDIDATES and INITIAL.  CANDIDATES is the
alist `display-buffer-pivot-tab-bar--get-candidates' returns.  INITIAL
is the initial input; an empty string means a new tab.  The function
returns the chosen name.  A completion frontend sets this to show its
own candidates and previews; the consult integration in
`ia-tab-bar-modified-consult' sets it to a reader with previews."
  :type '(choice (const :tag "completing-read" nil) function)
  :group 'display-buffer-pivot-tab-bar)

(defvar display-buffer-pivot-tab-bar--history nil
  "Tracked history list containing raw selection entries.")

;; --- Custom Faces ---

(defface display-buffer-pivot-tab-bar-index-face
  '((t :inherit font-lock-type-face))
  "Face for active tab indices."
  :group 'display-buffer-pivot-tab-bar)

(defface display-buffer-pivot-tab-bar-closed-face
  '((t :inherit shadow))
  "Face for closed history tab indicators."
  :group 'display-buffer-pivot-tab-bar)

(defface display-buffer-pivot-tab-bar-buffer-face
  '((t :inherit font-lock-doc-face))
  "Face for tab buffer names."
  :group 'display-buffer-pivot-tab-bar)

(defface display-buffer-pivot-tab-bar-window-face
  '((t :inherit font-lock-constant-face))
  "Face for tab window counts."
  :group 'display-buffer-pivot-tab-bar)

(defface display-buffer-pivot-tab-bar-group-face
  '((t :inherit font-lock-comment-face))
  "Face for tab group names."
  :group 'display-buffer-pivot-tab-bar)

;; --- Core Logic ---

(defun display-buffer-pivot-tab-bar-sort-active-first (cands candidates-alist)
  "Sort CANDS so live tabs dynamically bubble above closed history tabs.
CANDIDATES-ALIST is the alist that `display-buffer-pivot-tab-bar--get-candidates'
returns."
  (let ((active nil)
        (closed nil))
    (dolist (cand cands)
      (if (nth 1 (assoc-string cand candidates-alist))
          (push cand active)
        (push cand closed)))
    (setq active (sort active (lambda (a b)
                                (< (nth 1 (assoc-string a candidates-alist))
                                   (nth 1 (assoc-string b candidates-alist))))))
    (append active (nreverse closed))))

(defun display-buffer-pivot-tab-bar--extract-visible-buffers (ws)
  "Recursively extract only currently visible buffers from a window state WS."
  (let ((buffers nil))
    (cl-labels ((walk (node)
                  (cond
                   ((and (consp node) (eq (car node) 'buffer) (stringp (cadr node)))
                    (push (cadr node) buffers))
                   ((consp node)
                    (walk (car node))
                    (walk (cdr node))))))
      (walk ws))
    (nreverse buffers)))

(defun display-buffer-pivot-tab-bar--get-tab-data (tab)
  "Extract a static list of (BUFFER-STRING WINDOW-COUNT GROUP) from TAB."
  (let* ((ws (alist-get 'ws tab))
         (group (alist-get 'group tab))
         (is-current (eq (car tab) 'current-tab))
         buf-str win-count)

    (if is-current
        (let ((wins (window-list nil 'no-minibuf)))
          (setq win-count (length wins)
                buf-str (mapconcat (lambda (w) (buffer-name (window-buffer w))) wins " ")
                group (or group (frame-parameter nil 'tab-bar-group))))
      (if ws
          (let ((bufs (display-buffer-pivot-tab-bar--extract-visible-buffers ws)))
            (setq win-count (max 1 (length bufs))
                  buf-str (if bufs (mapconcat #'identity bufs " ") "unknown")))
        (setq win-count 0
              buf-str "unknown")))

    (list buf-str win-count group)))

(defun display-buffer-pivot-tab-bar--sanitize-history ()
  "Strip text properties and natively deduplicate the history list.
Prevents duplicates where visually identical strings fail `equal'
comparisons due to hidden text properties."
  (when display-buffer-pivot-tab-bar--history
    (setq display-buffer-pivot-tab-bar--history
          (delete-dups (mapcar #'substring-no-properties display-buffer-pivot-tab-bar--history)))))

(defun display-buffer-pivot-tab-bar--get-candidates (&optional force-history)
  "Generate a static snapshot alist for stable previews.
FORCE-HISTORY includes the closed names even when
`display-buffer-pivot-tab-bar-enable-history' is nil."
  (let* ((tabs (tab-bar-tabs))
         (active-names nil)
         (candidates nil)
         (name-counts (make-hash-table :test 'equal)))

    (cl-loop for tab in tabs
             for idx from 1
             for raw-name = (alist-get 'name tab)
             for data = (display-buffer-pivot-tab-bar--get-tab-data tab)
             for buffer = (nth 0 data)
             for win-count = (nth 1 data)
             for group = (nth 2 data)
             for count = (gethash raw-name name-counts 0)
             for unique-name = (if (= count 0) raw-name (format "%s<%d>" raw-name (1+ count)))
             do
             (puthash raw-name (1+ count) name-counts)
             (push raw-name active-names)
             (push (list unique-name idx raw-name buffer win-count group) candidates))
    (setq candidates (nreverse candidates))

    (if (not (or display-buffer-pivot-tab-bar-enable-history force-history))
        candidates
      (let ((history-cands nil)
            (seen-history nil))
        (dolist (hist-item display-buffer-pivot-tab-bar--history)
          (when (stringp hist-item)
            (unless (or (string= hist-item "")
                        (member hist-item active-names)
                        (member hist-item seen-history))
              (push hist-item seen-history)
              (push (list hist-item nil hist-item nil nil nil) history-cands))))
        (append candidates (nreverse history-cands))))))

(defun display-buffer-pivot-tab-bar-read-tab-name (&optional prompt initial)
  "Read a tab name with this package's candidates and history.
The live tabs come first, sorted by
`display-buffer-pivot-tab-bar-sort-function', followed by the closed
names in `display-buffer-pivot-tab-bar--history'.  The chosen name is
returned; selecting the tab or making a new one is the caller's.
PROMPT is the prompt string and defaults to \"Switch Workspace (or
create new): \".  INITIAL is the initial minibuffer input and defaults
to the current tab's name; pass \"\" when the empty name should mean a
new tab.  When `display-buffer-pivot-tab-bar-read-function' is
non-nil, call it with PROMPT, the candidate alist and INITIAL instead
of `completing-read'."
  (let* ((candidates (display-buffer-pivot-tab-bar--get-candidates))
         (names (mapcar #'car candidates))
         (prompt (or prompt "Switch Workspace (or create new): "))
         (current (or initial
                      (car (cl-find-if
                            (lambda (candidate)
                              (eq (nth 1 candidate)
                                  (1+ (tab-bar--current-tab-index))))
                            candidates)))))
    (unwind-protect
        (if display-buffer-pivot-tab-bar-read-function
            (funcall display-buffer-pivot-tab-bar-read-function
                     prompt candidates current)
          (let ((marginalia-annotators
                 (if display-buffer-pivot-tab-bar-disable-marginalia
                     nil
                   (bound-and-true-p marginalia-annotators)))
                (history-delete-duplicates t))
            (let ((completion-extra-properties
                   (list :category 'tab
                         :display-sort-function
                         (if display-buffer-pivot-tab-bar-sort-function
                             (lambda (cands)
                               (funcall display-buffer-pivot-tab-bar-sort-function
                                        cands candidates))
                           #'identity)
                         :affixation-function
                         (if display-buffer-pivot-tab-bar-disable-marginalia
                             (let ((annotator
                                    (display-buffer-pivot-tab-bar--build-annotator
                                     candidates)))
                               (lambda (cands) (mapcar annotator cands)))
                           nil))))
              (completing-read
               prompt
               names nil nil nil
               (and display-buffer-pivot-tab-bar-enable-history
                    'display-buffer-pivot-tab-bar--history)
               current))))
      (display-buffer-pivot-tab-bar--sanitize-history))))

(defun display-buffer-pivot-tab-bar--build-annotator (candidates)
  "Pre-calculate column widths for CANDIDATES and return an annotation closure."
  (let ((max-base 0) (max-win 0) (max-grp 0))

    ;; Pass 1: Measure maximum widths for grid alignment
    (dolist (item candidates)
      (let* ((cand (nth 0 item))
             (idx  (nth 1 item))
             (win  (nth 4 item))
             (grp  (nth 5 item))
             (base-w (+ (string-width cand) (if idx (length (format " [%d]" idx)) 9))) ; " (closed)" is 9 chars
             (win-w  (if win (length (format "win:%d" win)) 0))
             (grp-w  (if win (length (format "group:%s" (if (> (length grp) 0) grp "none"))) 0)))
        (setq max-base (max max-base base-w)
              max-win  (max max-win win-w)
              max-grp  (max max-grp grp-w))))

    ;; Pass 2: Return the closure that physically builds the string
    (lambda (cand)
      (let* ((match (assoc-string cand candidates))
             (idx   (nth 1 match))
             (buf   (nth 3 match))
             (win   (nth 4 match))
             (grp   (nth 5 match))
             (i-str (if idx (format " [%d]" idx) " (closed)"))
             (i-face (if idx 'display-buffer-pivot-tab-bar-index-face 'display-buffer-pivot-tab-bar-closed-face))
             (base-w (+ (string-width cand) (string-width i-str)))
             (pad-base (make-string (max 1 (+ (- max-base base-w) 4)) ?\s))
             (suffix (concat (propertize i-str 'face i-face) pad-base)))

        (when (and display-buffer-pivot-tab-bar-show-extra-states win)
          (let* ((w-str (format "win:%d" win))
                 (g-str (format "group:%s" (if (> (length grp) 0) grp "none")))
                 (w-pad (make-string (max 1 (+ (- max-win (length w-str)) 2)) ?\s))
                 (g-pad (make-string (max 1 (+ (- max-grp (length g-str)) 2)) ?\s)))
            (setq suffix (concat suffix
                                 (propertize w-str 'face 'display-buffer-pivot-tab-bar-window-face) w-pad
                                 (propertize g-str 'face 'display-buffer-pivot-tab-bar-group-face) g-pad
                                 (propertize buf 'face 'display-buffer-pivot-tab-bar-buffer-face)))))

        ;; Returning a 3-element list maps natively to Consult and Affixation UI
        (list cand "" suffix)))))

(defun display-buffer-pivot-tab-bar-remove-history-item ()
  "Selectively remove a specific item from the tab history."
  (interactive)
  (if (not display-buffer-pivot-tab-bar--history)
      (user-error "Tab history is already empty")
    (let ((target (completing-read "Remove history item: "
                                   display-buffer-pivot-tab-bar--history
                                   nil t)))
      (setq display-buffer-pivot-tab-bar--history
            (delete target display-buffer-pivot-tab-bar--history))
      (message "Removed '%s' from tab history." target))))

(defun display-buffer-pivot-tab-bar-clear-history ()
  "Completely clear the tab bar history."
  (interactive)
  (setq display-buffer-pivot-tab-bar--history nil)
  (message "Tab bar history cleared."))

(provide 'display-buffer-pivot-tab-bar)

;;; display-buffer-pivot-tab-bar.el ends here
