;;; disbuf-pivot-prefix.el --- Pivot prefix commands for windows, tabs and frames  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/display-buffer-pivot
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; The prefix commands set `display-buffer-overriding-action' for the next
;; command, as `other-window-prefix' does.
;; `disbuf-pivot-other-window-prefix' asks with `ace-window' and can split a
;; window; `disbuf-pivot-other-tab-prefix' asks for a tab and then for a
;; window of that tab; `disbuf-pivot-other-frame-prefix' asks for a frame,
;; its tab when it has more than one, and its window; a new frame name
;; makes a new frame with that name.  They replace `other-window-prefix',
;; `other-tab-prefix' and `other-frame-prefix'.
;;
;; A buffer displayed by `same-window-prefix' in a dedicated window does not
;; use the most recently used window, and `other-window-prefix' does the
;; opposite of `same-window-prefix'.  `disbuf-pivot-prefix-mode' solves
;; that problem: a prefix issued from a window that cannot display a buffer
;; acts on the last editing window of the frame, or of the parent frame when
;; a child frame is selected, not on that window.

(require 'cl-lib)
(require 'dp-window-utility)
(require 'disbuf-pivot)

;;; Code:

(defgroup dp-prefix nil
  "Pivot prefix commands for windows, tabs and frames."
  :group 'windows)

(defun dp-prefix--find-last-active-workspace ()
  "Return the most recently used editing window of the selected frame.
Use the parent frame when the selected frame is a child frame.  Leave out
minibuffer windows and windows that cannot display a buffer."
  (let* ((frame (selected-frame))
         (parent (frame-parent frame))
         (frame-windows (window-list (or parent frame) 'no-minibuf)))
    ;; Sort windows by their last interaction timestamp (newest first)
    (setq frame-windows (sort frame-windows
                              (lambda (w1 w2)
                                (> (window-use-time w1) (window-use-time w2)))))
    ;; Scan for the first editing window
    (cl-find-if (lambda (w)
                  (not (or (window-minibuffer-p w)
                           (dp-window-utility-cannot-display-p w))))
                frame-windows)))

(defun dp-prefix--ad-display-buffer (orig-fun buffer &optional action)
  "Intercept `display-buffer' before a window prefix runs.
ORIG-FUN is the original `display-buffer'; BUFFER and ACTION are its
arguments.  If a prefix rule is set and the selected window cannot
display a buffer, run the display with the last editing window of the
frame selected."
  (if (and display-buffer-overriding-action
           (not (equal display-buffer-overriding-action '(nil . nil))) ; Ensure a prefix actually sets an action
           (dp-window-utility-cannot-display-p (selected-window)))
      (let ((target-workspace (dp-prefix--find-last-active-workspace)))
        (if target-workspace
            ;; Run the display with the editing window selected
            (with-selected-window target-workspace
              (funcall orig-fun buffer action))
          (funcall orig-fun buffer action)))
    ;; Fall back to the standard behavior when no prefix action is set
    (funcall orig-fun buffer action)))

(defcustom dp-other-window-prefix-select t
  "Whether the window `aw-select' returns is selected.

`t' selects that window after the buffer is displayed, so the display
leaves point in the window the user chose.

`auto' selects nothing: the caller decides -- a caller that selects the
window it displayed (`pop-to-buffer') selects that window, and a caller
that does not select leaves the selected window alone.

`nil' selects nothing either, and undoes a caller that selects: at the
end of the command the window that was selected before the prompt is
selected again, the way `display-buffer' treats a `nil'
`post-command-select-window' entry."
  :type '(choice (const :tag "Always select" t)
                 (const :tag "Let the caller decide" auto)
                 (const :tag "Never select" nil))
  :group 'dp-prefix)

(defun dp-other-window-prefix ()
  "Display the buffer of the next command in an `ace-window` selected window.

You can bind this command to override `other-window-prefix' keybinding."
  (interactive)
  (display-buffer-override-next-command
   (lambda (buffer alist)
     (let ((aw-scope (cl-case (cdr (assq 'reusable-frames alist))
                       ((nil) 'frame)
                       (visible 'visible)
                       ((0 t) 'global)))
           (aw-ignore-current
            (or (cdr (assq 'inhibit-same-window alist))
                (dp-window-utility-cannot-display-p (selected-window))))
           window type)
       ;; If the current windows are less than the maximum amount, try
       ;; to pop up a new window, which also respects split
       ;; thresholds.  If it hits the limit, OR if popping up fails,
       ;; fall back to ace-window.
       (if (and (dp-window-utility-split-p)
                (setq window (display-buffer-pop-up-window buffer alist)))
           (setq type 'window)
         (let ((choice (dp-window-utility-choose-display-window aw-scope aw-ignore-current
                                                "Ace Window")))
           (if choice
               (progn
                 (setq window choice
                       type 'reuse)
                 (let ((answering (selected-window)))
                   (window--display-buffer buffer choice 'reuse alist)
                   (pcase dp-other-window-prefix-select
                     ('t (select-window choice))
                     ('nil (dp-window-utility-select-window-post-command answering)))))
             (setq window nil))))
       (cons window type)))
     nil "[disbuf-pivot-other-window-prefix]")
  (message "Display next command buffer in a window via ace-window..."))

(defvar dp-other-tab-prefix--in-progress nil
  "Non-nil while `disbuf-pivot-other-tab-prefix' chooses the tab and its window.")

(defun dp-other-tab-prefix ()
  "Display the buffer of the next command in a tab.
The next buffer is the buffer displayed by the next command invoked
immediately after this command.  When the merged action alist names
`reusable-frames', a tab that already displays the buffer is used first;
otherwise read a tab name, where an empty name makes a new tab, and an
existing name selects that tab.  The buffer is then displayed there by
`disbuf-pivot-action-functions'.

A display made while the tab step runs -- `tab-bar-new-tab-choice' may
display a buffer of its own -- is left to the other display rules, so it
does not show the tab prompt again."
  (interactive)
  (display-buffer-override-next-command
   (lambda (buffer alist)
     (if dp-other-tab-prefix--in-progress
         (cons nil 'reuse)
       (let ((dp-other-tab-prefix--in-progress t))
         (let ((result (dp-action-tab buffer alist)))
           (cons (car-safe result) (or (cdr-safe result) 'reuse))))))
   nil "[other-tab]")
  (message "Display next command buffer in a tab..."))

(defvar dp-other-frame-prefix--in-progress nil
  "Non-nil while `disbuf-pivot-other-frame-prefix' chooses its display.")

(defun dp-other-frame-prefix ()
  "Display the buffer of the next command in a frame.
The next buffer is the buffer displayed by the next command invoked
immediately after this command.  Read a frame name: an existing name
selects that frame, and when it has more than one tab, read a tab name
and select or make that tab.  A new name makes a new frame with that
name; an empty name makes a new frame with the default name and uses
its selected window.  In an existing frame, a window that already
displays the buffer is used; otherwise ask with `ace-window', where the
split dispatch keys split the chosen window.

A display made while the frame step runs is left to the other display
rules, so it does not show the frame prompt again."
  (interactive)
  (display-buffer-override-next-command
   (lambda (buffer alist)
     (if dp-other-frame-prefix--in-progress
         (cons nil 'reuse)
       (let ((dp-other-frame-prefix--in-progress t))
         (cons (dp-action--frame buffer alist) 'reuse))))
   nil "[other-frame]")
  (message "Display next command buffer in a frame..."))

;;;###autoload
(define-minor-mode dp-prefix-mode
  "Global minor mode for prefix commands from a dedicated or side window.
Such a prefix acts on the last editing window of the frame, or of the
parent frame when a child frame is selected."
  :global t
  :group 'dp-prefix
  (if dp-prefix-mode
      (advice-add 'display-buffer :around #'dp-prefix--ad-display-buffer)
    (advice-remove 'display-buffer #'dp-prefix--ad-display-buffer)))

;; Local Variables:
;; checkdoc-allow-quoting-nil-and-t: t
;; read-symbol-shorthands: (("dp-" . "disbuf-pivot-"))
;; End:

(provide 'dp-prefix)

;;; disbuf-pivot-prefix.el ends here
