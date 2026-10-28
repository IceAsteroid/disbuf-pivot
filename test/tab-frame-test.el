;;; -*- lexical-binding: t; -*-
;; Behavioural checks for the tab and frame target of
;; disbuf-pivot-action.  Run: make test
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

(defun tab-frame-checks ()
  (setq nfail 0)

(defvar w1) (defvar w2)
(setq w1 (selected-window))
(setq w2 (split-window w1 nil 'below))

;;; ---- what the ACTION and ALIST ask for
(let ((dp-action--action
       '((display-buffer-in-tab) (inhibit-same-window . nil))))
  (check "target: a tab action asks for a tab"
         (eq (dp-action--target
              '((inhibit-same-window . nil)))
             'tab)))
(let ((dp-action--action '((display-buffer-in-new-tab))))
  (check "target: a new-tab action asks for a tab"
         (eq (dp-action--target nil) 'tab)))
(let ((dp-action--action nil))
  (check "target: tab-name asks for a tab"
         (eq (dp-action--target '((tab-name . "x"))) 'tab))
  (check "target: pop-up-frames asks for a frame"
         (eq (dp-action--target '((pop-up-frames . t)))
             'frame)))
(let ((dp-action--action nil))
  (check "target: pop-up-frames nil asks for no frame"
         (null (dp-action--target '((pop-up-frames . nil))))))
(let ((dp-action--action '((display-buffer-pop-up-frame))))
  (check "target: a frame action asks for a frame"
         (eq (dp-action--target nil) 'frame)))
(let ((dp-action--action '((display-buffer-pop-up-window))))
  (check "target: a plain window action asks for no target"
         (null (dp-action--target nil))))
(let ((dp-action--action
       '((display-buffer-in-child-frame) (parent-frame . nil))))
  (check "target: a child frame is left to the caller"
         (null (dp-action--target '((parent-frame))))))

;;; ---- the frames the prompt may offer
(let ((parent (selected-frame))
      (child 'fake-child))
  (cl-letf (((symbol-function 'frame-list)
             (lambda () (list parent child)))
            ((symbol-function 'frame-live-p)
             (lambda (frame) (memq frame (list parent child))))
            ((symbol-function 'frame-visible-p)
             (lambda (_frame) t))
            ((symbol-function 'frame-parent)
             (lambda (frame) (and (eq frame child) parent)))
            ((symbol-function 'frame-parameter)
             (lambda (frame parameter)
               (and (eq parameter 'name)
                    (if (eq frame child) "child" "parent")))))
    (check "frames: a child frame is not offered"
           (equal (dp-action--frames nil) (list parent)))))

;;; ---- stubs
(defvar tab-calls)
(defvar ask-seen)
(defvar answers)
(setq tab-calls nil)
(defun tab-record (name &rest args)
  (push (cons name args) tab-calls))
(defun tab-stub-tabs ()
  '(((name . "one") (index . 0))
    ((name . "two") (index . 1))))
(defun ask-stub (mode-line)
  (setq ask-seen (list mode-line aw-scope aw-ignore-current
                       aw-dispatch-when-more-than aw-dispatch-always))
  w2)

;;; ---- the tab question and its window
(let ((noninteractive nil)
      (tab-calls nil)
      (ask-seen nil))
  (cl-letf (((symbol-function 'tab-bar-tabs) #'tab-stub-tabs)
            ((symbol-function 'tab-bar-select-tab)
             (lambda (index) (tab-record 'select index)))
            ((symbol-function 'tab-bar-new-tab)
             (lambda (&rest _) (tab-record 'new)))
            ((symbol-function 'tab-bar-rename-tab)
             (lambda (name) (tab-record 'rename name)))
            ((symbol-function 'tab-bar-change-tab-group)
             (lambda (group) (tab-record 'group group)))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select) #'ask-stub)
            ((symbol-function 'completing-read) (lambda (&rest _) "two")))
    (let ((result (dp-action-tab
                   (get-buffer-create "*tab1*") '((tab-name . "two")))))
      (check "tab: an existing name selects that tab"
             (and (eq (car-safe result) w2)
                  (eq (cdr-safe result) 'reuse)
                  (equal (nreverse tab-calls) '((select 2))))))))
(let ((noninteractive nil)
      (tab-calls nil)
      (ask-seen nil))
  (cl-letf (((symbol-function 'tab-bar-tabs) #'tab-stub-tabs)
            ((symbol-function 'tab-bar-new-tab)
             (lambda (&rest _) (tab-record 'new)))
            ((symbol-function 'tab-bar-rename-tab)
             (lambda (name) (tab-record 'rename name)))
            ((symbol-function 'tab-bar-change-tab-group)
             (lambda (group) (tab-record 'group group)))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select) #'ask-stub)
            ((symbol-function 'completing-read) (lambda (&rest _) "")))
    (let ((result (dp-action-tab
                   (get-buffer-create "*tab2*") '((tab-group . "work")))))
      (check "tab: an empty name makes a new tab"
             (and (eq (car-safe result) w2)
                  (eq (cdr-safe result) 'tab)
                  (equal (nreverse tab-calls) '((new) (group "work")))))))
  (check "tab: the window question uses the tab frame and reads a key"
         (equal ask-seen '("Display buffer in window" frame nil 0 nil))))
(let ((noninteractive nil)
      (tab-calls nil))
  (cl-letf (((symbol-function 'tab-bar-tabs) #'tab-stub-tabs)
            ((symbol-function 'tab-bar-new-tab)
             (lambda (&rest _) (tab-record 'new)))
            ((symbol-function 'tab-bar-rename-tab)
             (lambda (name) (tab-record 'rename name)))
            ((symbol-function 'tab-bar-change-tab-group)
             (lambda (group) (tab-record 'group group)))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select) #'ask-stub)
            ((symbol-function 'completing-read) (lambda (&rest _) "three")))
    (let ((result (dp-action-tab
                   (get-buffer-create "*tab3*") nil)))
      (check "tab: a new name makes a tab with that name"
             (and (eq (car-safe result) w2)
                  (eq (cdr-safe result) 'tab)
                  (equal (nreverse tab-calls)
                         '((new) (rename "three"))))))))

;;; ---- a window already showing the buffer
(let ((noninteractive nil)
      (ask-calls 0))
  (cl-letf (((symbol-function 'tab-bar-tabs) #'tab-stub-tabs)
            ((symbol-function 'tab-bar-select-tab) #'ignore)
            ((symbol-function 'get-buffer-window) (lambda (&rest _) w2))
            ((symbol-function 'aw-select)
             (lambda (&rest _) (setq ask-calls (1+ ask-calls)) w1)))
    (let ((result (dp-action-tab
                   (get-buffer-create "*tab-reuse*") '((tab-name . "two")))))
      (check "tab: a window showing the buffer is reused without a question"
             (and (eq (car-safe result) w2)
                  (eq (cdr-safe result) 'reuse)
                  (zerop ask-calls))))))

;;; ---- a chosen window that cannot display asks again
(let ((noninteractive nil)
      (calls 0))
  (set-window-dedicated-p w1 t)
  (cl-letf (((symbol-function 'tab-bar-tabs) #'tab-stub-tabs)
            ((symbol-function 'tab-bar-select-tab) #'ignore)
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select)
             (lambda (&rest _)
               (setq calls (1+ calls))
               (if (= calls 1) w1 w2))))
    (let ((result (dp-action-tab
                   (get-buffer-create "*tab-ask*") '((tab-name . "two")))))
      (check "tab: a dedicated choice asks again"
             (and (eq (car-safe result) w2) (= calls 2)))))
  (set-window-dedicated-p w1 nil))

;;; ---- the tab package's reader supplies the name
(let ((original (symbol-function 'dp-tab-bar-read-tab-name)))
  (unwind-protect
      (progn
        (let (reader-args)
          (fset 'dp-tab-bar-read-tab-name
                (lambda (&optional prompt initial)
                  (setq reader-args (list prompt initial))
                  "two"))
          (let ((noninteractive nil)
                (tab-calls nil)
                (reader-calls 0))
            (cl-letf (((symbol-function 'tab-bar-tabs) #'tab-stub-tabs)
                      ((symbol-function 'tab-bar-select-tab)
                       (lambda (index) (tab-record 'select index)))
                      ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
                      ((symbol-function 'aw-select) #'ask-stub)
                      ((symbol-function 'completing-read)
                       (lambda (&rest _) (setq reader-calls (1+ reader-calls)) "")))
              (let ((result (dp-action-tab
                             (get-buffer-create "*tab-reader*") nil)))
                (check "tab: the tab package's reader supplies the name"
                       (and (eq (car-safe result) w2)
                            (equal (nreverse tab-calls) '((select 2)))
                            (zerop reader-calls)))
                (check "tab: the display action asks the reader with its prompt"
                       (equal reader-args
                              '("Display buffer in tab (empty for a new tab): "
                                ""))))))))
    (fset 'dp-tab-bar-read-tab-name original)))

;;; ---- the reader function set by a completion frontend
(let* ((seen nil)
       (dp-tab-bar--history nil)
       (dp-tab-bar-read-function
        (lambda (prompt candidates initial)
          (setq seen (list prompt candidates initial))
          "two")))
  (cl-letf (((symbol-function 'tab-bar-tabs) #'tab-stub-tabs))
    (check "reader function: it reads the name"
           (equal (dp-tab-bar-read-tab-name
                   "Prompt: " "two")
                  "two"))
    (check "reader function: it gets the prompt, candidates and initial"
           (and (equal (nth 0 seen) "Prompt: ")
                (equal (nth 2 seen) "two")
                (equal (mapcar #'car (nth 1 seen)) '("one" "two"))))))

;;; ---- a duplicate tab name selects its own tab
(let ((tabs '(((name . "dup") (index . 0))
              ((name . "dup") (index . 1))))
      (tab-calls nil)
      (noninteractive nil))
  (cl-letf (((symbol-function 'tab-bar-tabs) (lambda () tabs))
            ((symbol-function 'tab-bar-select-tab)
             (lambda (index) (push (list 'select index) tab-calls)))
            ((symbol-function 'tab-bar-new-tab)
             (lambda (&rest _) (push '(new) tab-calls)))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select) #'ask-stub))
    (dp-action-tab
     (get-buffer-create "*tab-dup*") '((tab-name . "dup<2>")))
    (check "tab: a duplicate name selects its own tab"
           (equal (nreverse tab-calls) '((select 2))))))

;;; ---- inhibit-same-window in the tab path
(let ((noninteractive nil)
      (aw-called 0))
  (select-window w1)
  (cl-letf (((symbol-function 'get-buffer-window)
             (lambda (&rest _) (selected-window)))
            ((symbol-function 'aw-select)
             (lambda (&rest _)
               (setq aw-called (1+ aw-called))
               w2)))
    (let ((result (dp-action--display-in-tab
                   (get-buffer-create "*tab-inhibit*")
                   '((inhibit-same-window . t)))))
      (check "tab: inhibit-same-window declines the selected window"
             (and (eq (car-safe result) w2) (= aw-called 1))))))

;;; ---- the split help follows the user's dispatch list
(let ((aw-dispatch-alist
       '((?s aw-split-window-vert "Split Vert Window")
         (?x aw-delete-window "Delete Window"))))
  (let ((actions (dp-window-utility--split-actions)))
    (check "split help: the user's split key is used"
           (string-match-p "s: Split Vert Window"
                           (dp-window-utility--split-help actions)))
    (check "split help: a delete action is left out"
           (not (string-match-p "Delete Window"
                                (dp-window-utility--split-help actions))))))

;;; ---- the sole window's key
(let ((aw-dispatch-alist '((?s aw-split-window-vert "Split Test"))))
  (cl-letf (((symbol-function 'read-char) (lambda (&rest _) ?x)))
    (check "sole window: any other key uses it"
           (eq (dp-window-utility-choose-sole-window w1) w1)))
  (cl-letf (((symbol-function 'read-char) (lambda (&rest _) ?s))
            ((symbol-function 'aw-split-window-vert)
             (lambda (_window) w2)))
    (check "sole window: a split key uses the new window"
           (eq (dp-window-utility-choose-sole-window w1) w2))))
(let ((aw-dispatch-alist '((?s aw-split-window-vert "Split Test"))))
  (select-window w1)
  (cl-letf (((symbol-function 'read-char) (lambda (&rest _) ?x)))
    (check "sole window: an ignored selected window cancels"
           (null (dp-window-utility-choose-sole-window w1 t)))))

;;; ---- batch asks nothing
(let ((noninteractive t))
  (check "tab: batch asks nothing"
         (null (dp-action-tab
                (get-buffer-create "*tab4*") '((tab-name . "four")))))
  (check "frame: batch asks nothing"
         (null (dp-action--frame
                (get-buffer-create "*frame3*") '((pop-up-frames . t))))))

;;; ---- the frame question
(let ((noninteractive nil)
      (calls nil))
  (cl-letf (((symbol-function 'dp-action--frames)
             (lambda (&rest _) (list (selected-frame))))
            ((symbol-function 'completing-read)
             (lambda (&rest _)
               (or (frame-parameter (selected-frame) 'name) "frame")))
            ((symbol-function 'select-frame-set-input-focus)
             (lambda (frame) (setq calls (list 'focus frame))))
            ((symbol-function 'select-frame)
             (lambda (frame) (setq calls (list 'select frame))))
            ((symbol-function 'tab-bar-tabs) (lambda () '(((name . "one")))))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select) #'ask-stub))
    (check "frame: a name selects that frame"
           (and (eq (dp-action--frame
                     (get-buffer-create "*frame1*") nil)
                    w2)
                (eq (cadr calls) (selected-frame))))))
(let ((noninteractive nil)
      (calls nil)
      (named nil))
  (cl-letf (((symbol-function 'dp-action--frames)
             (lambda (&rest _) (list (selected-frame))))
            ((symbol-function 'completing-read)
             (lambda (&rest _) ""))
            ((symbol-function 'display-buffer-pop-up-frame)
             (lambda (&rest _) (setq calls (list 'new)) w2))
            ((symbol-function 'set-frame-parameter)
             (lambda (&rest _) (setq named t))))
    (check "frame: an empty name makes a new frame"
           (and (eq (dp-action--frame
                     (get-buffer-create "*frame2*")
                     '((pop-up-frames . t)))
                    w2)
                (equal calls '(new))
                (not named)))))
(let ((noninteractive nil)
      (tab-calls nil)
      (answers (list (frame-parameter (selected-frame) 'name) "two")))
  (cl-letf (((symbol-function 'dp-action--frames)
             (lambda (&rest _) (list (selected-frame))))
            ((symbol-function 'completing-read)
             (lambda (&rest _) (pop answers)))
            ((symbol-function 'select-frame-set-input-focus) #'ignore)
            ((symbol-function 'tab-bar-tabs)
             (lambda ()
               '(((name . "one") (index . 0))
                 ((name . "two") (index . 1)))))
            ((symbol-function 'tab-bar-select-tab)
             (lambda (index) (tab-record 'select index)))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select) #'ask-stub))
    (check "frame: a frame with several tabs asks the tab, then the window"
           (and (eq (dp-action--frame
                     (get-buffer-create "*frame4*") nil)
                    w2)
                (equal (nreverse tab-calls) '((select 2)))))))

;;; ---- a repeated frame name selects the second frame
(let ((noninteractive nil)
      (frames (list 'frame-one 'frame-two))
      (focus nil))
  (cl-letf (((symbol-function 'dp-action--frames)
             (lambda (&rest _) frames))
            ((symbol-function 'frame-parameter)
             (lambda (_frame parameter)
               (and (eq parameter 'name) "same")))
            ((symbol-function 'completing-read)
             (lambda (&rest _) "same<2>"))
            ((symbol-function 'select-frame-set-input-focus)
             (lambda (frame) (setq focus frame)))
            ((symbol-function 'tab-bar-tabs)
             (lambda () '(((name . "one")))))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select) #'ask-stub))
    (check "frame: a repeated name selects the second frame"
           (and (eq (dp-action--frame
                     (get-buffer-create "*frame-dup*") nil)
                    w2)
                (eq focus 'frame-two)))))

;;; ---- a new frame name makes a named frame
(let ((noninteractive nil)
      (popped nil)
      (named nil))
  (cl-letf (((symbol-function 'dp-action--frames)
             (lambda (&rest _) (list (selected-frame))))
            ((symbol-function 'completing-read)
             (lambda (&rest _) "fresh"))
            ((symbol-function 'display-buffer-pop-up-frame)
             (lambda (&rest _) (setq popped t) w2))
            ((symbol-function 'set-frame-parameter)
             (lambda (frame parameter value)
               (setq named (list frame parameter value)))))
    (check "frame: a new name makes a named frame"
           (and (eq (dp-action--frame
                     (get-buffer-create "*frame-new-name*") nil)
                    w2)
                popped
                (equal named
                       (list (window-frame w2) 'name "fresh"))))))

;;; ---- the core tab action through display-buffer
(dp-action-mode +1)
(let ((noninteractive nil)
      (asked 0)
      (made 0))
  (cl-letf (((symbol-function 'tab-bar-new-tab)
             (lambda (&rest _) (setq made (1+ made))))
            ((symbol-function 'tab-bar-tabs) #'tab-stub-tabs)
            ((symbol-function 'tab-bar-select-tab) #'ignore)
            ((symbol-function 'tab-bar-rename-tab) #'ignore)
            ((symbol-function 'tab-bar-change-tab-group) #'ignore)
            ((symbol-function 'completing-read)
             (lambda (&rest _) (setq asked (1+ asked)) ""))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select) #'ask-stub))
    (let ((win (display-buffer (get-buffer-create "*tab-core*")
                               '((display-buffer-in-tab)
                                 (inhibit-same-window . nil)))))
      (check "core: a tab ACTION reaches the tab question"
             (and (eq win w2) (= asked 1) (= made 1))))))

;;; ---- the core frame action through display-buffer
(let ((noninteractive nil)
      (asked 0)
      (popped 0))
  (cl-letf (((symbol-function 'dp-action--frames)
             (lambda (&rest _) nil))
            ((symbol-function 'completing-read)
             (lambda (&rest _) (setq asked (1+ asked)) ""))
            ((symbol-function 'display-buffer-pop-up-frame)
             (lambda (&rest _) (setq popped (1+ popped)) w2)))
    (let ((win (display-buffer (get-buffer-create "*frame-core*")
                               display-buffer--other-frame-action)))
      (check "core: an other-frame ACTION reaches the frame question"
             (and (eq win w2) (= asked 1) (= popped 1))))))

;;; ---- the reusable tab
(let ((noninteractive nil)
      (calls nil))
  (cl-letf (((symbol-function 'tab-bar-get-buffer-tab)
             (lambda (&rest _) (list (cons 'frame (selected-frame))
                                     (cons 'index 0))))
            ((symbol-function 'select-frame-set-input-focus)
             (lambda (frame) (push (list 'focus frame) calls)))
            ((symbol-function 'tab-bar-select-tab)
             (lambda (index) (push (list 'select index) calls)))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) w2)))
    (let ((result (dp-action-tab
                   (get-buffer-create "*tab-reuse2*")
                   '((reusable-frames . t)))))
      (check "tab: a reusable tab is selected before the window rule"
             (and (eq (car-safe result) w2)
                  (eq (cdr-safe result) 'reuse)
                  (equal (nreverse calls)
                         (list (list 'focus (selected-frame))
                               (list 'select 1))))))))

;;; ---- the other-tab prefix
(let ((noninteractive nil))
  (cl-letf (((symbol-function 'dp-action-tab)
             (lambda (_buffer _alist) (cons w2 'tab))))
    (dp-other-tab-prefix)
    (let ((win (display-buffer (get-buffer-create "*otp*"))))
      (check "other-tab prefix: the tab step decides"
             (and (eq win w2)
                  (eq (window-buffer w2) (get-buffer "*otp*")))))))
(let ((noninteractive nil)
      (calls 0))
  (cl-letf (((symbol-function 'dp-action-tab)
             (lambda (_buffer _alist)
               (setq calls (1+ calls))
               (display-buffer (get-buffer-create "*nested*"))
               (cons w2 'tab))))
    (dp-other-tab-prefix)
    (let ((win (display-buffer (get-buffer-create "*outer*"))))
      (check "other-tab prefix: a nested display does not ask again"
             (and (eq win w2)
                  (= calls 1)
                  (eq (window-buffer w2) (get-buffer "*outer*")))))))
(dp-action-mode -1)

(princ (if (zerop nfail) "\nALL PASSED\n"
         (format "\n%d CHECK(S) FAILED\n" nfail)))
(expect nfail :to-be 0))

(describe "ia tab and frame target"
  (it "runs the tab and frame checks"
    (tab-frame-checks)))
;; Local Variables:
;; read-symbol-shorthands: (("dp-" . "disbuf-pivot-"))
;; End:
