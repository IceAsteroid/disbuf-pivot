;;; disbuf-pivot-prefix.el --- Pivot prefix commands for windows, tabs and frames  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/disbuf-pivot
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; The prefix commands set `display-buffer-overriding-action' for the next
;; command, as `other-window-prefix' does.  They choose the last editing
;; window of the frame, or of the parent frame when a child frame is
;; selected, when the selected window cannot display a buffer.
;; `disbuf-pivot-same-window-prefix' displays in that window;
;; `disbuf-pivot-other-window-prefix' asks with `ace-window' and can split
;; a window; `disbuf-pivot-other-tab-prefix' asks for a tab and then for a
;; window of that tab; `disbuf-pivot-other-frame-prefix' asks for a frame,
;; its tab when `tab-bar-mode' is active or the frame has more than one,
;; and its window; a new frame name makes a new frame with that name.
;; `disbuf-pivot-prefix-mode' remaps
;; `same-window-prefix', `other-window-prefix', `other-tab-prefix', and
;; `other-frame-prefix' to these commands; it does not advise
;; `display-buffer'.

(require 'cl-lib)
(require 'dp-window-utility)
(require 'disbuf-pivot)

;;; Code:

(defgroup dp-prefix nil
  "Pivot prefix commands for windows, tabs and frames."
  :group 'windows)

(defun dp-prefix--find-last-active-window ()
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

(defun dp-prefix--with-editing-window (function)
  "Call FUNCTION with the editing window selected when one is needed.
When the selected window cannot display a buffer, select the most
recently used editing window of the frame, or of the parent frame when a
child frame is selected.  FUNCTION runs with that window selected, and
the previous selection is restored when it returns."
  (let ((window (if (dp-window-utility-cannot-display-p (selected-window))
                    (dp-prefix--find-last-active-window)
                  (selected-window))))
    (if (and window (not (eq window (selected-window))))
        (with-selected-window window (funcall function))
      (funcall function))))

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
  "Display the buffer of the next command in an `ace-window' selected window.
`disbuf-pivot-prefix-mode' remaps `other-window-prefix' to this command."
  (interactive)
  (display-buffer-override-next-command
   (lambda (buffer alist)
     (let (choice answering result)
       (setq result
             (dp-prefix--with-editing-window
              (lambda ()
                (let ((aw-scope (cl-case (cdr (assq 'reusable-frames alist))
                                  ((nil) 'frame)
                                  (visible 'visible)
                                  ((0 t) 'global)))
                      (aw-ignore-current
                       (or (cdr (assq 'inhibit-same-window alist))
                           (dp-window-utility-cannot-display-p
                            (selected-window))))
                      window type)
                  ;; If the current windows are less than the maximum amount,
                  ;; try to pop up a new window, which also respects split
                  ;; thresholds.  If it hits the limit, OR if popping up
                  ;; fails, fall back to ace-window.
                  (if (and (dp-window-utility-split-p)
                           (setq window
                                 (display-buffer-pop-up-window buffer alist)))
                      (setq type 'window)
                    (setq choice (dp-window-utility-choose-display-window
                                  aw-scope aw-ignore-current))
                    (if choice
                        (progn
                          (setq window choice
                                type 'reuse
                                answering (selected-window))
                          (window--display-buffer buffer choice 'reuse alist))
                      (setq window nil)))
                  (cons window type)))))
       (when choice
         (pcase dp-other-window-prefix-select
           ('t (select-window choice))
           ('nil (dp-window-utility-select-window-post-command answering))))
       result))
   nil "[disbuf-pivot-other-window-prefix]")
  (message "Display next command buffer in a window via ace-window..."))

(defun dp-same-window-prefix ()
  "Display the buffer of the next command in the same window.
When the selected window cannot display a buffer, use the most recently
used editing window of the frame, or of the parent frame when a child
frame is selected.  `disbuf-pivot-prefix-mode' remaps
`same-window-prefix' to this command."
  (interactive)
  (display-buffer-override-next-command
   (lambda (buffer alist)
     (dp-prefix--with-editing-window
      (lambda ()
        (let ((alist (cons '(inhibit-same-window . nil) alist)))
          (cons (or (display-buffer-same-window buffer alist)
                    (display-buffer-use-some-window buffer alist))
                'reuse)))))
   nil "[same-window]")
  (message "Display next command buffer in the same window..."))

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
     (dp-prefix--with-editing-window
      (lambda ()
        (if dp-other-tab-prefix--in-progress
            (cons nil 'reuse)
          (let ((dp-other-tab-prefix--in-progress t))
            (let ((result (dp-action-tab buffer alist)))
              (cons (car-safe result) (or (cdr-safe result) 'reuse))))))))
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
     (dp-prefix--with-editing-window
      (lambda ()
        (if dp-other-frame-prefix--in-progress
            (cons nil 'reuse)
          (let ((dp-other-frame-prefix--in-progress t))
            (cons (dp-action--frame buffer alist) 'reuse))))))
   nil "[other-frame]")
  (message "Display next command buffer in a frame..."))

(defvar-keymap dp-prefix-mode-map
  :doc "Keymap for `disbuf-pivot-prefix-mode'."
  "<remap> <same-window-prefix>" #'dp-same-window-prefix
  "<remap> <other-window-prefix>" #'dp-other-window-prefix
  "<remap> <other-tab-prefix>" #'dp-other-tab-prefix
  "<remap> <other-frame-prefix>" #'dp-other-frame-prefix)

;;;###autoload
(define-minor-mode dp-prefix-mode
  "Global minor mode that remaps the built-in prefix commands.
When enabled, the bindings of `same-window-prefix',
`other-window-prefix', `other-tab-prefix', and `other-frame-prefix'
run the package's prefix commands.  A built-in command invoked by name
or from a menu is unchanged."
  :global t
  :keymap dp-prefix-mode-map
  :group 'dp-prefix)

;; Local Variables:
;; checkdoc-allow-quoting-nil-and-t: t
;; read-symbol-shorthands: (("dp-" . "disbuf-pivot-"))
;; End:

(provide 'dp-prefix)

;;; disbuf-pivot-prefix.el ends here
