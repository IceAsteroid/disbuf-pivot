;;; -*- lexical-binding: t; -*-
;; Behavioural checks for disbuf-pivot-action-mode and the prefix
;; commands.  Run: make test
(require 'disbuf-pivot)
(require 'dp-prefix)
(require 'buttercup)

(defvar nfail 0)
(defmacro check (label form)
  `(let ((val (condition-case err ,form (error (format "ERROR %S" err)))))
     (if (and val (not (stringp val)))
         (princ (format "ok   %s => %S\n" ,label val))
       (progn (setq nfail (1+ nfail))
              (princ (format "FAIL %s => %S\n" ,label val))))))

(defun display-ask-checks ()
  (setq nfail 0)

;;; ---- the entry, the mode's install and its removal
(check "mode off: no entry"
       (null (assq 'dp-action-control-p display-buffer-alist)))
(dp-action-mode +1)
(check "mode on: the entry is first when column-popup's is absent"
       (eq (caar display-buffer-alist)
           'dp-action-control-p))
(check "mode on: `display-buffer-base-action' is untouched"
       (equal display-buffer-base-action '(nil . nil)))
(dp-action-mode -1)
(check "mode off: the entry is removed"
       (null (assq 'dp-action-control-p display-buffer-alist)))
(check "mode off: `display-buffer-base-action' is still untouched"
       (equal display-buffer-base-action '(nil . nil)))

;; enabling twice leaves one entry; disabling twice removes it once
(dp-action-mode +1)
(dp-action-mode +1)
(check "enable twice: one entry"
       (= 1 (length (cl-remove-if-not
                     (lambda (e) (eq (car e) 'dp-action-control-p))
                     display-buffer-alist))))
(dp-action-mode -1)
(dp-action-mode -1)
(check "disable twice: no entry"
       (null (assq 'dp-action-control-p display-buffer-alist)))

;; the entry is consed at the front, above another package's entry
(let ((display-buffer-alist
       (list (cons 'column-popup-display-control-p '((ignore))))))
  (dp-action-mode +1)
  (check "the entry is consed at the front"
         (and (eq (caar display-buffer-alist)
                  'dp-action-control-p)
              (eq (car (nth 1 display-buffer-alist))
                  'column-popup-display-control-p)))
  (dp-action-mode -1)
  (check "disabling leaves the other entry alone"
         (and (= 1 (length display-buffer-alist))
              (eq (caar display-buffer-alist)
                  'column-popup-display-control-p))))
(dp-action-mode +1)

;;; ---- layout: w1 above w2
(defvar w1) (defvar w2)
(setq w1 (selected-window))
(setq w2 (split-window w1 nil 'below))

;;; ---- the split rule: under the maximum, split before asking
(let ((windows (list w1 w2)))
  (cl-letf (((symbol-function 'aw-window-list) (lambda () windows)))
    (let ((dp-window-utility-split-maximum 3))
      (check "split: two windows are under a maximum of three"
             (dp-window-utility-split-p)))
    (let ((dp-window-utility-split-maximum 2))
      (check "split: two windows are not under a maximum of two"
             (not (dp-window-utility-split-p))))
    (set-window-dedicated-p w2 t)
    (let ((dp-window-utility-split-maximum 2)
          (dp-window-utility-split-maximum-exclude-dedicated t))
      (check "split: a dedicated window is left out"
             (dp-window-utility-split-p)))
    (let ((dp-window-utility-split-maximum 2)
          (dp-window-utility-split-maximum-exclude-dedicated nil))
      (check "split: a dedicated window is counted when not excluded"
             (not (dp-window-utility-split-p))))
    (set-window-dedicated-p w2 nil)))
(let ((side (display-buffer-in-side-window (get-buffer-create "*side-free*")
                                           '((side . right))))
      (windows nil))
  (setq windows (list w1 side))
  (cl-letf (((symbol-function 'aw-window-list) (lambda () windows)))
    (let ((dp-window-utility-split-maximum 2)
          (dp-window-utility-split-maximum-exclude-side t))
      (check "split: a side window is left out"
             (dp-window-utility-split-p)))
    (let ((dp-window-utility-split-maximum 2)
          (dp-window-utility-split-maximum-exclude-side nil)
          (dp-window-utility-split-maximum-exclude-dedicated nil))
      (check "split: a side window is counted when not excluded"
             (not (dp-window-utility-split-p)))))
  (delete-window side))

;;; ---- the action function splits under the maximum, asks at it
(let ((noninteractive nil)
      (dp-action-select 'auto)
      (split-calls 0)
      (ask-calls 0)
      (windows (list w1 w2)))
  (cl-letf (((symbol-function 'aw-window-list) (lambda () windows))
            ((symbol-function 'display-buffer-pop-up-window)
             (lambda (_buffer _alist) (setq split-calls (1+ split-calls)) w2))
            ((symbol-function 'aw-select)
             (lambda (&rest _) (setq ask-calls (1+ ask-calls)) w2)))
    (let ((dp-window-utility-split-maximum 4))
      (check "split-or-ask: under the maximum, the split decides"
             (and (eq (dp-action-split-or-ask
                       (get-buffer-create "*split*") nil)
                      w2)
                  (= split-calls 1)
                  (= ask-calls 0))))
    (setq split-calls 0)
    (let ((dp-window-utility-split-maximum 2))
      (check "split-or-ask: at the maximum, the question decides"
             (and (eq (dp-action-split-or-ask
                       (get-buffer-create "*split2*") nil)
                      w2)
                  (= split-calls 0)
                  (= ask-calls 1))))
    (setq split-calls 0
          ask-calls 0)
    (cl-letf (((symbol-function 'display-buffer-pop-up-window)
               (lambda (&rest _) nil)))
      (let ((dp-window-utility-split-maximum 4))
        (check "split-or-ask: a failed split asks"
               (and (eq (dp-action-split-or-ask
                         (get-buffer-create "*split3*") nil)
                        w2)
                    (= split-calls 0)
                    (= ask-calls 1)))))))

;; The question path is what the rest of the checks below exercise.
(setq dp-window-utility-split-maximum 0)

;;; ---- the rule, with the batch gate lifted and aw-select stubbed
(let ((noninteractive nil))
  ;; a plain selected window takes the buffer; the choice never runs
  (let ((calls 0))
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _) (setq calls (1+ calls)) nil)))
      (let ((result (display-buffer (get-buffer-create "*t1*"))))
        (check "plain window: the buffer takes the selected window"
               (eq result w1))
        (check "plain window: the choice never runs" (= calls 0)))))
  ;; a dedicated selected window asks; a dedicated choice asks again
  (set-window-dedicated-p w1 t)
  (let* ((dp-action-select 'auto)
         (w3 (split-window w2 nil 'below))
         (calls 0)
         (choices (list w2 w3)))
    (set-window-dedicated-p w2 t)
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _)
                 (setq calls (1+ calls))
                 (pop choices))))
      (let ((result (display-buffer (get-buffer-create "*t2*"))))
        (check "dedicated choice: asked again" (= calls 2))
        (check "dedicated choice: the second choice gets the buffer"
               (eq result w3))
        (check "dedicated choice: the buffer is in the chosen window"
               (eq (window-buffer w3) (get-buffer "*t2*")))))
    (set-window-dedicated-p w2 nil)
    (delete-window w3))
  ;; an aborted choice declines and the following action functions run
  (let ((result nil))
    (cl-letf (((symbol-function 'aw-select) (lambda (&rest _) nil)))
      (setq result (display-buffer (get-buffer-create "*t3*"))))
    (check "aborted choice: a window is still returned"
           (and result (window-live-p result))))
  ;; in batch the rule declines without choosing
  (let ((noninteractive t)
        (calls 0)
        (result nil))
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _) (setq calls (1+ calls)) nil)))
      (setq result (display-buffer (get-buffer-create "*t4*"))))
    (check "batch gate: the choice never runs" (= calls 0))
    (check "batch gate: a window is still returned"
           (and result (window-live-p result))))
  ;; a request that names a place is left to the caller
  (let ((calls 0))
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _) (setq calls (1+ calls)) w2)))
      (let ((win (display-buffer (get-buffer-create "*side*")
                                 '((display-buffer-in-side-window)
                                   (side . right)))))
        (check "a side request is left to the caller"
               (and (= calls 0)
                    (eq (window-parameter win 'window-side) 'right))))))
  ;; t selects the chosen window
  (select-window w1)
  (let ((dp-action-select t))
    (cl-letf (((symbol-function 'aw-select) (lambda (&rest _) w2)))
      (display-buffer (get-buffer-create "*t5*"))
      (check "select t: the chosen window is selected"
             (eq (selected-window) w2))))
  ;; auto selects nothing and installs nothing
  (select-window w1)
  (let ((dp-action-select 'auto)
        (post-command-hook nil))
    (cl-letf (((symbol-function 'aw-select) (lambda (&rest _) w2)))
      (display-buffer (get-buffer-create "*t6*"))
      (check "select auto: the selection is unchanged"
             (eq (selected-window) w1))
      (check "select auto: no entry is installed"
             (null post-command-hook))))
  ;; nil undoes a caller that selects, at the end of the command
  (select-window w1)
  (let ((dp-action-select nil)
        (post-command-hook nil))
    (cl-letf (((symbol-function 'aw-select) (lambda (&rest _) w2)))
      (let ((pop-up-windows t))
        (pop-to-buffer (get-buffer-create "*t7*") t))
      (check "select nil: the caller selected during the command"
             (eq (selected-window) w2))
      (check "select nil: one entry is installed"
             (= 1 (length post-command-hook)))
      (run-hooks 'post-command-hook)
      (check "select nil: the selection returns at the end of the command"
             (eq (selected-window) w1))
      (check "select nil: the entry removed itself"
             (null post-command-hook))))
  (select-window w1)
  (set-window-dedicated-p w1 nil))

;;; ---- the function list, read at display time
(let ((noninteractive nil)
      (probe (get-buffer-create "*list-default*")))
  (set-window-buffer w2 probe)
  (select-window w1)
  (let ((dp-action-functions
         '(display-buffer-reuse-window
           display-buffer-same-window
           dp-action-choose-window)))
    (let ((win (display-buffer probe)))
      (check "the default list: one view, the existing window wins"
             (and (eq win w2)
                  (= 1 (length (get-buffer-window-list probe nil nil)))))))
  (set-window-buffer w1 (get-buffer-create "*other*")))
(let ((noninteractive nil)
      (probe (get-buffer-create "*list-same*")))
  (set-window-buffer w2 probe)
  (select-window w1)
  (let ((dp-action-functions
         '(display-buffer-same-window
           dp-action-choose-window)))
    (let ((win (display-buffer probe)))
      (check "a reordered list: two views, the selected window wins"
             (and (eq win w1)
                  (= 2 (length (get-buffer-window-list probe nil nil)))))))
  (set-window-buffer w1 (get-buffer-create "*other2*")))
;; without the chooser the rule never asks
(let ((noninteractive nil)
      (calls 0))
  (set-window-dedicated-p w1 t)
  (let ((dp-action-functions '(display-buffer-reuse-window)))
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _) (setq calls (1+ calls)) nil)))
      (display-buffer (get-buffer-create "*night*"))
      (check "a list without the chooser never asks" (= calls 0))))
  (set-window-dedicated-p w1 nil))

;;; ---- the patched prefix: the ace path asks again on a utility choice
(let ((noninteractive nil)
      (pop-up-windows nil)
      (calls 0)
      (mode-lines nil)
      (messages nil))
  (set-window-dedicated-p w2 t)
  (dp-other-window-prefix)
  (let ((choices (list w2 w1)))
    (cl-letf (((symbol-function 'display-buffer-pop-up-window)
               (lambda (&rest _) nil))
              ((symbol-function 'aw-select)
               (lambda (mode-line)
                 (push mode-line mode-lines)
                 (setq calls (1+ calls))
                 (pop choices)))
              ((symbol-function 'message)
               (lambda (format-string &rest args)
                 (push (apply #'format format-string args) messages))))
      (let ((result (display-buffer (get-buffer-create "*t9*"))))
        (check "prefix: a dedicated choice asked again" (= calls 2))
        (check "prefix: the repeat uses a separate mode line"
               (equal (nreverse mode-lines)
                      '("Display buffer in window (? for actions)"
                        "Choose another window (? for actions)")))
        (check "prefix: the repeat explains in the echo area"
               (equal (nreverse messages)
                      '("disbuf-pivot: the chosen window cannot display the buffer; choose another")))
        (check "prefix: the buffer is in the second choice"
               (eq (window-buffer w1) (get-buffer "*t9*")))
        (check "prefix: the display returns that window" (eq result w1)))))
  (set-window-dedicated-p w2 nil))

;;; ---- the prefix splits under the maximum
(let ((noninteractive nil)
      (pop-up-windows nil)
      (split-calls 0)
      (ask-calls 0)
      (dp-window-utility-split-maximum 4))
  (select-window w1)
  (cl-letf (((symbol-function 'aw-window-list) (lambda () (list w1 w2)))
            ((symbol-function 'display-buffer-pop-up-window)
             (lambda (_buffer _alist) (setq split-calls (1+ split-calls)) w2))
            ((symbol-function 'aw-select)
             (lambda (&rest _) (setq ask-calls (1+ ask-calls)) w1)))
    (dp-other-window-prefix)
    (let ((result (display-buffer (get-buffer-create "*prefix-split*"))))
      (check "prefix: under the maximum, the split decides"
             (and (eq result w2)
                  (= split-calls 1)
                  (= ask-calls 0))))))

;;; ---- the prefix's select option
(let ((noninteractive nil)
      (pop-up-windows nil))
  (select-window w1)
  (let ((dp-other-window-prefix-select t))
    (dp-other-window-prefix)
    (cl-letf (((symbol-function 'display-buffer-pop-up-window)
               (lambda (&rest _) nil))
              ((symbol-function 'aw-select) (lambda (&rest _) w2)))
      (display-buffer (get-buffer-create "*t10*"))
      (check "prefix select t: the chosen window is selected"
             (eq (selected-window) w2))))
  (setq display-buffer-overriding-action '(nil . nil))
  (select-window w1)
  (let ((dp-other-window-prefix-select 'auto))
    (dp-other-window-prefix)
    (cl-letf (((symbol-function 'display-buffer-pop-up-window)
               (lambda (&rest _) nil))
              ((symbol-function 'aw-select) (lambda (&rest _) w2)))
      (display-buffer (get-buffer-create "*t11*"))
      (check "prefix select auto: the selection is unchanged"
             (eq (selected-window) w1))))
  (setq display-buffer-overriding-action '(nil . nil))
  (select-window w1)
  (let ((dp-other-window-prefix-select nil))
    (dp-other-window-prefix)
    (cl-letf (((symbol-function 'display-buffer-pop-up-window)
               (lambda (&rest _) nil))
              ((symbol-function 'aw-select) (lambda (&rest _) w2)))
      (pop-to-buffer (get-buffer-create "*t12*") t))
    (check "prefix select nil: the caller selected during the command"
           (eq (selected-window) w2))
    (run-hooks 'post-command-hook)
    (check "prefix select nil: the selection returns at the end"
           (eq (selected-window) w1)))
  (setq display-buffer-overriding-action '(nil . nil)))

;;; ---- the prefix's ace scope and same-window exclusion
(let ((noninteractive nil)
      (pop-up-windows nil)
      (ask-scope nil)
      (ask-ignore nil))
  (select-window w1)
  (cl-letf (((symbol-function 'display-buffer-pop-up-window)
             (lambda (&rest _) nil))
            ((symbol-function 'aw-select)
             (lambda (&rest _)
               (setq ask-scope aw-scope
                     ask-ignore aw-ignore-current)
               w2)))
    (unwind-protect
        (progn
          (dp-other-window-prefix)
          (display-buffer
           (get-buffer-create "*prefix-scope*")
           '(nil (reusable-frames . visible)
             (inhibit-same-window . t)))
          (check "prefix: the ace scope follows reusable-frames"
                 (eq ask-scope 'visible))
          (check "prefix: inhibit-same-window reaches ace-window"
                 ask-ignore))
      (setq display-buffer-overriding-action '(nil . nil)))))

;;; ---- the pivot searches the parent frame
(let ((windows (list w1 w2))
      (seen nil))
  (cl-letf (((symbol-function 'selected-frame) (lambda () 'child))
            ((symbol-function 'frame-parent)
             (lambda (frame) (and (eq frame 'child) 'parent)))
            ((symbol-function 'window-list)
             (lambda (frame &optional _minibuf)
               (setq seen frame)
               windows)))
    (let ((result (dp-prefix--find-last-active-window)))
      (check "pivot: a child frame searches its parent frame"
             (and (eq seen 'parent)
                  (memq result windows))))))

;;; ---- the default list reaches the split rule
(let ((noninteractive nil)
      (split-height-threshold 10)
      (split-width-threshold 20)
      (dp-window-utility-split-maximum 4)
      (ask-calls 0))
  (set-window-dedicated-p w1 t)
  (select-window w1)
  (cl-letf (((symbol-function 'aw-window-list) (lambda () (list w1 w2)))
            ((symbol-function 'aw-select)
             (lambda (&rest _) (setq ask-calls (1+ ask-calls)) nil)))
    (let ((probe (get-buffer-create "*default-split*")))
      (let ((win (display-buffer probe)))
        (check "default list: under the maximum, `display-buffer' splits"
               (and win
                    (not (eq win w1))
                    (= ask-calls 0)
                    (eq (window-buffer win) probe))))))
  (set-window-dedicated-p w1 nil))

;;; ---- one window: a request for another window splits instead of reusing it
(let ((noninteractive nil)
      (pop-up-windows t)
      (split-height-threshold 10)
      (split-width-threshold 20))
  (delete-other-windows)
  (let ((start (selected-window)))
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _) (selected-window))))
      (let* ((probe (get-buffer-create "*one-window*"))
             (win (display-buffer probe t)))
        (check "one window, ACTION t: a new window is split"
               (and win
                    (not (eq win start))
                    (= 2 (length (window-list)))
                    (eq (window-buffer win) probe)))
        (check "one window, ACTION t: the selected window keeps its buffer"
               (not (eq (window-buffer start) probe)))))))

;;; ---- the prefix mode remaps the built-in prefix commands
(dp-prefix-mode +1)
(dolist (pair '((same-window-prefix . dp-same-window-prefix)
                (other-window-prefix . dp-other-window-prefix)
                (other-tab-prefix . dp-other-tab-prefix)
                (other-frame-prefix . dp-other-frame-prefix)))
  (check (format "prefix mode: remaps %s" (car pair))
         (eq (lookup-key dp-prefix-mode-map
                         (vector 'remap (car pair)))
             (cdr pair))))
(check "prefix mode: C-x 4 1 runs the same-window command"
       (eq (key-binding (kbd "C-x 4 1")) #'dp-same-window-prefix))
(check "prefix mode: C-x 4 4 runs the other-window command"
       (eq (key-binding (kbd "C-x 4 4")) #'dp-other-window-prefix))
(check "prefix mode: C-x t t runs the other-tab command"
       (eq (key-binding (kbd "C-x t t")) #'dp-other-tab-prefix))
(check "prefix mode: C-x 5 5 runs the other-frame command"
       (eq (key-binding (kbd "C-x 5 5")) #'dp-other-frame-prefix))
(dp-prefix-mode -1)
(check "prefix mode off: C-x 4 1 runs the built-in command"
       (eq (key-binding (kbd "C-x 4 1")) #'same-window-prefix))

;;; ---- the same-window prefix chooses the editing window itself
(let ((noninteractive nil)
      (pop-up-windows nil))
  (delete-other-windows)
  (let* ((editing (selected-window))
         (dedicated (split-window editing nil 'below))
         (probe (get-buffer-create "*same-window-prefix*")))
    (select-window dedicated)
    (set-window-dedicated-p dedicated t)
    (dp-same-window-prefix)
    (let ((window (display-buffer probe)))
      (check "same-window prefix: the editing window gets the buffer"
             (and (eq window editing)
                  (eq (window-buffer editing) probe)))
      (check "same-window prefix: the dedicated window keeps its buffer"
             (not (eq (window-buffer dedicated) probe))))
    (set-window-dedicated-p dedicated nil)
    (delete-window dedicated)))

;;; ---- the mode's disable removes only its entry
(dp-action-mode -1)
(check "final: the entry is removed, `display-buffer-base-action' untouched"
       (and (null (assq 'dp-action-control-p display-buffer-alist))
            (equal display-buffer-base-action '(nil . nil))))

(princ (if (zerop nfail) "\nALL PASSED\n"
         (format "\n%d CHECK(S) FAILED\n" nfail)))
(expect nfail :to-be 0))

(describe "ia display action"
  (it "runs the display checks"
    (display-ask-checks)))
;; Local Variables:
;; read-symbol-shorthands: (("dp-" . "disbuf-pivot-"))
;; End:
