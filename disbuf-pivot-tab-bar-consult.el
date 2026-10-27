;;; disbuf-pivot-tab-bar-consult.el --- Consult reader for tab names  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/display-buffer-pivot
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; The consult reader for a tab name and the mode that installs it.
;; The tab bar library uses `completing-read' unless
;; `disbuf-pivot-tab-bar-read-function' is set; this library
;; supplies a function with consult previews.  It deletes child frames
;; before saving the window state, because PGTK deadlocks when that state
;; contains invisible Corfu frames, and it preserves the minibuffer
;; height while a preview selects a tab.  It requires `consult`; the core
;; disbuf-pivot package does not.  The tab-switch commands and
;; overrides are in `ia-tab-bar-modified-consult' in the `emacs-utils'
;; repository, which consumes this library.

;;; Code:

(require 'consult)
(require 'dp-tab-bar)

;; Pacify the compiler for the dynamic binding.
(defvar marginalia-annotators)

(defun dp-tab-bar-consult-purge-child-frames ()
  "Delete every child frame before a tab prompt saves the window state.
`current-window-configuration' captures invisible Corfu frames.  Restoring
that state during an active minibuffer blocks the PGTK display server.
`disbuf-pivot-tab-bar-consult-read' calls this function first; a
caller that saves a window configuration during a tab prompt can call it
too."
  (dolist (frame (frame-list))
    (when (frame-parent frame)
      (delete-frame frame))))

(defun dp-tab-bar-consult--select-tab (index)
  "Select tab INDEX while preserving the active minibuffer height."
  (let* ((mini (active-minibuffer-window))
         (h (and mini (window-height mini))))
    (tab-bar-select-tab index)
    (when (and mini (window-live-p mini) h)
      (let ((delta (- h (window-height mini))))
        (unless (zerop delta)
          (ignore-errors (window-resize mini delta)))))))

(defvar dp-tab-bar-consult-select-tab-function
  #'dp-tab-bar-consult--select-tab
  "Function to select a tab while a consult preview is shown.
It is called with the 1-based tab index.  The default preserves the
active minibuffer height; a caller can bind a function that performs
another cleanup.")

(defun dp-tab-bar-consult--state (candidates orig-index
                                                              orig-tabs orig-wc)
  "Return the consult state function for CANDIDATES.
ORIG-INDEX is the current tab's 1-based index, ORIG-TABS its tab list,
and ORIG-WC the window configuration to restore when the preview ends."
  (lambda (action cand)
    (cond
     ((and (eq action 'preview) cand)
      (let* ((match (assoc-string cand candidates))
             (target-idx (nth 1 match)))
        (when target-idx
          (funcall dp-tab-bar-consult-select-tab-function
                   target-idx))))
     ((and (eq action 'preview) (not cand))
      (funcall dp-tab-bar-consult-select-tab-function
               orig-index))
     ((eq action 'return)
      (set-frame-parameter nil 'tabs orig-tabs)
      (set-window-configuration orig-wc)
      (funcall dp-tab-bar-consult-select-tab-function
               orig-index)))))

(defun dp-tab-bar-consult-read (prompt candidates initial)
  "Read a tab name from CANDIDATES with consult previews.
PROMPT is the prompt string.  INITIAL is the default candidate; an
empty string means a new tab.  Return the chosen name."
  (dp-tab-bar-consult-purge-child-frames)
  (let* ((orig-index (1+ (tab-bar--current-tab-index)))
         (orig-tabs (copy-tree (frame-parameter nil 'tabs)))
         (orig-wc (current-window-configuration))
         (marginalia-annotators
          (if dp-tab-bar-disable-marginalia
              nil
            (bound-and-true-p marginalia-annotators)))
         (history-delete-duplicates t)) ; Force native deduplication
    (unwind-protect
        (let ((completion-extra-properties
               (list :category 'tab
                     :display-sort-function
                     (if dp-tab-bar-sort-function
                         (lambda (cands)
                           (funcall dp-tab-bar-sort-function
                                    cands candidates))
                       #'identity))))
          (consult--read
           candidates
           :prompt prompt
           :default initial
           :category 'tab
           :sort nil
           :history (and dp-tab-bar-enable-history
                         'dp-tab-bar--history)
           :require-match nil
           :annotate (if dp-tab-bar-disable-marginalia
                         (dp-tab-bar--build-annotator
                          candidates)
                       nil)
           :state (dp-tab-bar-consult--state
                   candidates orig-index orig-tabs orig-wc)))
      ;; Unconditional cleanup
      (dp-tab-bar--sanitize-history))))

(defun dp-tab-bar-consult-read-tab-name
    (prompt candidates initial)
  "Read a tab name with consult previews.
PROMPT, CANDIDATES and INITIAL are the arguments
`disbuf-pivot-tab-bar-read-function' receives."
  (dp-tab-bar-consult-read prompt candidates initial))

(defvar dp-tab-bar-consult--read-function nil
  "The tab reader to restore when the consult mode is disabled.")

(define-minor-mode dp-tab-bar-consult-mode
  "Use consult previews when reading a tab name.
When enabled, set `disbuf-pivot-tab-bar-read-function' to
`disbuf-pivot-tab-bar-consult-read-tab-name'.  When disabled,
restore the previous value."
  :global t
  :group 'dp-tab-bar
  (if dp-tab-bar-consult-mode
      (progn
        (setq dp-tab-bar-consult--read-function
              dp-tab-bar-read-function)
        (setq dp-tab-bar-read-function
              #'dp-tab-bar-consult-read-tab-name))
    (when (eq dp-tab-bar-read-function
              #'dp-tab-bar-consult-read-tab-name)
      (setq dp-tab-bar-read-function
            dp-tab-bar-consult--read-function))))

(provide 'dp-tab-bar-consult)

;;; disbuf-pivot-tab-bar-consult.el ends here
;; Local Variables:
;; read-symbol-shorthands: (("dp-" . "disbuf-pivot-"))
;; End:
