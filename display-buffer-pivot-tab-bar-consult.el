;;; display-buffer-pivot-tab-bar-consult.el --- Consult reader for tab names  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/display-buffer-pivot
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; The consult reader for a tab name and the mode that installs it.
;; The tab bar library uses `completing-read' unless
;; `display-buffer-pivot-tab-bar-read-function' is set; this library
;; supplies a function with consult previews.  It deletes child frames
;; before saving the window state, because PGTK deadlocks when that state
;; contains invisible Corfu frames, and it preserves the minibuffer
;; height while a preview selects a tab.  It requires `consult`; the core
;; display-buffer-pivot package does not.  The tab-switch commands and
;; overrides are in `ia-tab-bar-modified-consult' in the `emacs-utils'
;; repository, which consumes this library.

;;; Code:

(require 'consult)
(require 'display-buffer-pivot-tab-bar)

;; Pacify the compiler for the dynamic binding.
(defvar marginalia-annotators)

(defun display-buffer-pivot-tab-bar-consult-purge-child-frames ()
  "Delete every child frame before a tab prompt saves the window state.
`current-window-configuration' captures invisible Corfu frames.  Restoring
that state during an active minibuffer blocks the PGTK display server.
`display-buffer-pivot-tab-bar-consult-read' calls this function first; a
caller that saves a window configuration during a tab prompt can call it
too."
  (dolist (frame (frame-list))
    (when (frame-parent frame)
      (delete-frame frame))))

(defun display-buffer-pivot-tab-bar-consult--select-tab (index)
  "Select tab INDEX while preserving the active minibuffer height."
  (let* ((mini (active-minibuffer-window))
         (h (and mini (window-height mini))))
    (tab-bar-select-tab index)
    (when (and mini (window-live-p mini) h)
      (let ((delta (- h (window-height mini))))
        (unless (zerop delta)
          (ignore-errors (window-resize mini delta)))))))

(defvar display-buffer-pivot-tab-bar-consult-select-tab-function
  #'display-buffer-pivot-tab-bar-consult--select-tab
  "Function to select a tab while a consult preview is shown.
It is called with the 1-based tab index.  The default preserves the
active minibuffer height; a caller can bind a function that performs
another cleanup.")

(defun display-buffer-pivot-tab-bar-consult--state (candidates orig-index
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
          (funcall display-buffer-pivot-tab-bar-consult-select-tab-function
                   target-idx))))
     ((and (eq action 'preview) (not cand))
      (funcall display-buffer-pivot-tab-bar-consult-select-tab-function
               orig-index))
     ((eq action 'return)
      (set-frame-parameter nil 'tabs orig-tabs)
      (set-window-configuration orig-wc)
      (funcall display-buffer-pivot-tab-bar-consult-select-tab-function
               orig-index)))))

(defun display-buffer-pivot-tab-bar-consult-read (prompt candidates initial)
  "Read a tab name from CANDIDATES with consult previews.
PROMPT is the prompt string.  INITIAL is the default candidate; an
empty string means a new tab.  Return the chosen name."
  (display-buffer-pivot-tab-bar-consult-purge-child-frames)
  (let* ((orig-index (1+ (tab-bar--current-tab-index)))
         (orig-tabs (copy-tree (frame-parameter nil 'tabs)))
         (orig-wc (current-window-configuration))
         (marginalia-annotators
          (if display-buffer-pivot-tab-bar-disable-marginalia
              nil
            (bound-and-true-p marginalia-annotators)))
         (history-delete-duplicates t)) ; Force native deduplication
    (unwind-protect
        (let ((completion-extra-properties
               (list :category 'tab
                     :display-sort-function
                     (if display-buffer-pivot-tab-bar-sort-function
                         (lambda (cands)
                           (funcall display-buffer-pivot-tab-bar-sort-function
                                    cands candidates))
                       #'identity))))
          (consult--read
           candidates
           :prompt prompt
           :default initial
           :category 'tab
           :sort nil
           :history (and display-buffer-pivot-tab-bar-enable-history
                         'display-buffer-pivot-tab-bar--history)
           :require-match nil
           :annotate (if display-buffer-pivot-tab-bar-disable-marginalia
                         (display-buffer-pivot-tab-bar--build-annotator
                          candidates)
                       nil)
           :state (display-buffer-pivot-tab-bar-consult--state
                   candidates orig-index orig-tabs orig-wc)))
      ;; Unconditional cleanup
      (display-buffer-pivot-tab-bar--sanitize-history))))

(defun display-buffer-pivot-tab-bar-consult-read-tab-name
    (prompt candidates initial)
  "Read a tab name with consult previews.
PROMPT, CANDIDATES and INITIAL are the arguments
`display-buffer-pivot-tab-bar-read-function' receives."
  (display-buffer-pivot-tab-bar-consult-read prompt candidates initial))

(defvar display-buffer-pivot-tab-bar-consult--read-function nil
  "The tab reader to restore when the consult mode is disabled.")

(define-minor-mode display-buffer-pivot-tab-bar-consult-mode
  "Use consult previews when reading a tab name.
When enabled, set `display-buffer-pivot-tab-bar-read-function' to
`display-buffer-pivot-tab-bar-consult-read-tab-name'.  When disabled,
restore the previous value."
  :global t
  :group 'display-buffer-pivot-tab-bar
  (if display-buffer-pivot-tab-bar-consult-mode
      (progn
        (setq display-buffer-pivot-tab-bar-consult--read-function
              display-buffer-pivot-tab-bar-read-function)
        (setq display-buffer-pivot-tab-bar-read-function
              #'display-buffer-pivot-tab-bar-consult-read-tab-name))
    (when (eq display-buffer-pivot-tab-bar-read-function
              #'display-buffer-pivot-tab-bar-consult-read-tab-name)
      (setq display-buffer-pivot-tab-bar-read-function
            display-buffer-pivot-tab-bar-consult--read-function))))

(provide 'display-buffer-pivot-tab-bar-consult)

;;; display-buffer-pivot-tab-bar-consult.el ends here
