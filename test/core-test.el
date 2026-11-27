;;; core-test.el --- Buttercup tests for Milestone 1 core foundations  -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for Section 2 window predicates, Section 8 core options and
;; faces, Section 10 cannot-prompt guards and safe `dp-action--action'
;; reentrancy, and `disbuf-pivot-exclude-conditions'.

;;; Code:

(require 'buttercup)
(require 'cl-lib)
(require 'cus-edit)
(require 'disbuf-pivot)
(require 'dp-prefix)
(require 'dp-window-utility)
(require 'dp-tab-bar)

(describe "disbuf-pivot core options and faces"
  (it "defines all Section 8 options with their specified defaults"
    (expect (default-value 'dp-reuse) :to-be 'auto)
    (expect (default-value 'dp-same-window-conflict) :to-be 'ask)
    (expect (default-value 'dp-header-info) :to-be t)
    (expect (default-value 'dp-exclude-conditions) :to-be nil)
    (expect (default-value 'dp-action-select) :to-be 'auto)
    (expect (default-value 'dp-tab-prompt-scope) :to-be nil)
    (expect (default-value 'dp-window-keys)
            :to-equal '(?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9))
    (expect (default-value 'dp-split-actions)
            :to-equal '((?b split-window-below "Split below")
                        (?r split-window-right "Split right")
                        (?f dp-window-utility-split-fair "Split fair")))
    (expect (default-value 'dp-menu-min-column-width) :to-be 20)
    (expect (default-value 'dp-menu-min-height) :to-be 5)
    ;; Validate Customize types and group hierarchy
    (dolist (sym '(dp-reuse
                   dp-same-window-conflict
                   dp-header-info
                   dp-exclude-conditions
                   dp-action-select
                   dp-tab-prompt-scope
                   dp-window-keys
                   dp-split-actions
                   dp-menu-min-column-width
                   dp-menu-min-height))
      (let ((widget (widget-convert (get sym 'custom-type))))
        (expect (widget-apply widget :match (default-value sym))
                :to-be-truthy)))
    (dolist (sym '(dp-menu-min-column-width dp-menu-min-height))
      (let ((widget (widget-convert (get sym 'custom-type))))
        (expect (widget-apply widget :match 0) :to-be nil)
        (expect (widget-apply widget :match -1) :to-be nil)
        (expect (widget-apply widget :match 1) :to-be-truthy)))
    (let ((members (get 'disbuf-pivot 'custom-group)))
      (expect (member '(dp-action custom-group) members) :to-be-truthy)
      (expect (member '(dp-tab-bar custom-group) members) :to-be-truthy)
      (expect (member '(dp-prefix custom-group) members) :to-be-truthy)))

  (it "defines the eligible and ineligible window label faces"
    (expect (facep 'dp-eligible-label) :to-be-truthy)
    (expect (facep 'dp-ineligible-label) :to-be-truthy))

  (it "splits fairly by aspect ratio, falls back on tight axes, and handles dedicated windows"
    (delete-other-windows)
    (let* ((w1 (selected-window))
           (buf (get-buffer-create "*fair-split*")))
      (set-window-buffer w1 buf)
      (set-window-dedicated-p w1 t)
      (unwind-protect
          (let (w2 w3)
            (unwind-protect
                (progn
                  ;; Batch frame is 80x24: 80 > 2*23, so splits right.
                  (setq w2 (dp-window-utility-split-fair w1))
                  (expect (window-live-p w2) :to-be-truthy)
                  (expect (window-dedicated-p w1) :to-be-truthy)
                  (expect (window-dedicated-p w2) :to-be nil)
                  (expect (window-in-direction 'right w1) :to-be w2)
                  ;; Half-width window (~40x24): 40 <= 2*23, so splits below.
                  (setq w3 (dp-window-utility-split-fair w2))
                  (expect (window-live-p w3) :to-be-truthy)
                  (expect (window-in-direction 'below w2) :to-be w3))
              (when (window-live-p w3) (delete-window w3))
              (when (window-live-p w2) (delete-window w2))))
        (set-window-dedicated-p w1 nil)
        (kill-buffer buf)))
    ;; 18x8 TTY window: prefers right (17 > 2*7), cannot split right
    ;; (18 < 2*10), so falls back to split-window-below cleanly.
    (delete-other-windows)
    (let* ((w1 (selected-window))
           (w-right (split-window w1 18 'right))
           (w-below (split-window w1 8 'below))
           w-fair)
      (unwind-protect
          (progn
            (setq w-fair (dp-window-utility-split-fair w1))
            (expect (window-live-p w-fair) :to-be-truthy)
            (expect (window-in-direction 'below w1) :to-be w-fair)
            ;; Now w1 is 18x4: too small in both axes -> signals error.
            (expect (dp-window-utility-split-fair w1) :to-throw 'error))
        (when (window-live-p w-fair) (delete-window w-fair))
        (when (window-live-p w-below) (delete-window w-below))
        (when (window-live-p w-right) (delete-window w-right))))
    ;; Default nil/omitted window argument splits the selected window.
    (delete-other-windows)
    (let ((w1 (selected-window))
          w-default)
      (unwind-protect
          (progn
            (setq w-default (dp-window-utility-split-fair))
            (expect (window-live-p w-default) :to-be-truthy)
            (expect (window-in-direction 'right w1) :to-be w-default))
        (when (window-live-p w-default) (delete-window w-default))))
    ;; window-size-fixed falls back to the alternate axis and errors when both are fixed.
    (delete-other-windows)
    (let* ((w1 (selected-window))
           (buf (get-buffer-create "*fair-split-fixed*"))
           w-below w-half w-right)
      (set-window-buffer w1 buf)
      (unwind-protect
          (progn
            ;; Wide 80x24 window prefers right, but fixed width forces split below.
            (with-current-buffer buf
              (setq-local window-size-fixed 'width))
            (setq w-below (dp-window-utility-split-fair w1))
            (expect (window-live-p w-below) :to-be-truthy)
            (expect (window-in-direction 'below w1) :to-be w-below)
            (delete-window w-below)
            (setq w-below nil)
            ;; Half-width ~40x24 window prefers below, but fixed height forces split right.
            (with-current-buffer buf
              (setq-local window-size-fixed nil))
            (setq w-half (split-window-right nil w1))
            (set-window-buffer w-half buf)
            (with-current-buffer buf
              (setq-local window-size-fixed 'height))
            (setq w-right (dp-window-utility-split-fair w-half))
            (expect (window-live-p w-right) :to-be-truthy)
            (expect (window-in-direction 'right w-half) :to-be w-right)
            (delete-window w-right)
            (setq w-right nil)
            ;; Both axes fixed -> signals error.
            (with-current-buffer buf
              (setq-local window-size-fixed t))
            (expect (dp-window-utility-split-fair w-half) :to-throw 'error)
            ;; Non-selected window with fixed width splits that window below
            ;; without changing the selected window.
            (delete-window w-half)
            (setq w-half nil)
            (with-current-buffer buf
              (setq-local window-size-fixed 'width))
            (let ((w-top (selected-window))
                  (w-bot (split-window-below nil w1))
                  (buf-top (get-buffer-create "*fair-split-sel*"))
                  w-bot-split)
              (unwind-protect
                  (progn
                    (set-window-buffer w-top buf-top)
                    (set-window-buffer w-bot buf)
                    (select-window w-top)
                    (setq w-bot-split (dp-window-utility-split-fair w-bot))
                    (expect (window-live-p w-bot-split) :to-be-truthy)
                    (expect (window-in-direction 'below w-bot) :to-be w-bot-split)
                    (expect (selected-window) :to-be w-top))
                (when (window-live-p w-bot-split) (delete-window w-bot-split))
                (when (window-live-p w-bot) (delete-window w-bot))
                (kill-buffer buf-top))))
        (when (window-live-p w-right) (delete-window w-right))
        (when (window-live-p w-half) (delete-window w-half))
        (when (window-live-p w-below) (delete-window w-below))
        (kill-buffer buf)))
    ;; When both directions error, the primary error (including its error
    ;; symbol) is re-signaled, and quit (C-g) is never caught by fallback.
    (delete-other-windows)
    (let* ((w1 (selected-window))
           (w-half nil))
      (unwind-protect
          (progn
            ;; Wide 80x24 window prefers right: primary error is from split-window-right.
            (cl-letf (((symbol-function 'split-window-right)
                       (lambda (&rest _) (user-error "primary-right-err")))
                      ((symbol-function 'split-window-below)
                       (lambda (&rest _) (error "fallback-below-err"))))
              (let ((caught (condition-case err
                                (dp-window-utility-split-fair w1)
                              (error err))))
                (expect caught :to-equal '(user-error "primary-right-err"))))
            ;; Half-width ~40x24 window prefers below: primary error is from split-window-below.
            (setq w-half (split-window-right nil w1))
            (cl-letf (((symbol-function 'split-window-below)
                       (lambda (&rest _) (error "primary-below-err")))
                      ((symbol-function 'split-window-right)
                       (lambda (&rest _) (error "fallback-right-err"))))
              (let ((caught (condition-case err
                                (dp-window-utility-split-fair w-half)
                              (error err))))
                (expect caught :to-equal '(error "primary-below-err"))))
            ;; quit (C-g) propagates without invoking the fallback direction.
            (let ((fallback-called nil))
              (cl-letf (((symbol-function 'split-window-below)
                         (lambda (&rest _) (signal 'quit nil)))
                        ((symbol-function 'split-window-right)
                         (lambda (&rest _) (setq fallback-called t) w-half)))
                (expect (condition-case nil
                            (progn (dp-window-utility-split-fair w-half)
                                   'returned)
                          (quit 'quitted))
                        :to-be 'quitted)
                (expect fallback-called :to-be nil)))
            (delete-window w-half)
            (setq w-half nil)
            (let ((fallback-called nil))
              (cl-letf (((symbol-function 'split-window-right)
                         (lambda (&rest _) (signal 'quit nil)))
                        ((symbol-function 'split-window-below)
                         (lambda (&rest _) (setq fallback-called t) w1)))
                (expect (condition-case nil
                            (progn (dp-window-utility-split-fair w1)
                                   'returned)
                          (quit 'quitted))
                        :to-be 'quitted)
                (expect fallback-called :to-be nil))))
        (when (window-live-p w-half) (delete-window w-half))))
    ;; Side, minibuffer, and dead windows signal error; atomic constituent splits root.
    (delete-other-windows)
    (let* ((w1 (selected-window))
           (buf-side (get-buffer-create "*fair-split-side*"))
           (buf-atom (get-buffer-create "*fair-split-atom*"))
           (w-side (display-buffer-in-side-window buf-side '((side . right))))
           (w-dead (split-window-below nil w1))
           w-other w-atom w-atom-split)
      (delete-window w-dead)
      (unwind-protect
          (progn
            (expect (dp-window-utility-split-fair w-side) :to-throw 'error)
            (expect (dp-window-utility-split-fair (minibuffer-window))
                    :to-throw 'error)
            (expect (dp-window-utility-split-fair w-dead) :to-throw 'error)
            ;; Create an atomic window on a non-root sibling so cleanup works.
            (setq w-other (split-window-below nil w1))
            (setq w-atom (display-buffer-in-atom-window
                          buf-atom `((window . ,w-other) (side . right))))
            (setq w-atom-split (dp-window-utility-split-fair w-atom))
            (expect (window-live-p w-atom-split) :to-be-truthy)
            (expect (window-parameter w-atom-split 'window-atom) :to-be nil))
        (when (window-live-p w-atom-split) (delete-window w-atom-split))
        (when (and w-atom (window-valid-p (window-parent w-atom)))
          (delete-window (window-parent w-atom)))
        (when (window-live-p w-side) (delete-window w-side))
        (kill-buffer buf-atom)
        (kill-buffer buf-side)))
    ;; Graphic display pixel body comparison branch (tall and wide)
    (delete-other-windows)
    (let* ((w1 (selected-window))
           (orig-bw (symbol-function 'window-body-width))
           (orig-bh (symbol-function 'window-body-height))
           w-gui w-half w-gui-wide)
      (unwind-protect
          (progn
            (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _) t))
                      ((symbol-function 'window-body-width)
                       (lambda (&optional win pixelwise)
                         (if pixelwise 300 (funcall orig-bw win))))
                      ((symbol-function 'window-body-height)
                       (lambda (&optional win pixelwise)
                         (if pixelwise 600 (funcall orig-bh win)))))
              ;; Tall in pixels (300 <= 600) -> splits below even on 80x24 frame.
              (setq w-gui (dp-window-utility-split-fair w1))
              (expect (window-live-p w-gui) :to-be-truthy)
              (expect (window-in-direction 'below w1) :to-be w-gui))
            (delete-window w-gui)
            (setq w-gui nil)
            (setq w-half (split-window-right nil w1))
            (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _) t))
                      ((symbol-function 'window-body-width)
                       (lambda (&optional win pixelwise)
                         (if pixelwise 600 (funcall orig-bw win))))
                      ((symbol-function 'window-body-height)
                       (lambda (&optional win pixelwise)
                         (if pixelwise 300 (funcall orig-bh win)))))
              ;; Wide in pixels (600 > 300) -> splits right even on ~40x24 window.
              (setq w-gui-wide (dp-window-utility-split-fair w-half))
              (expect (window-live-p w-gui-wide) :to-be-truthy)
              (expect (window-in-direction 'right w-half) :to-be w-gui-wide)))
        (when (window-live-p w-gui-wide) (delete-window w-gui-wide))
        (when (window-live-p w-half) (delete-window w-half))
        (when (window-live-p w-gui) (delete-window w-gui))))))

(describe "disbuf-pivot window predicates"
  (it "classifies normal, dedicated, side, minibuffer, dead, and unsplittable windows"
    (delete-other-windows)
    (let* ((w1 (selected-window))
           (w2 (split-window w1 nil 'below))
           (buf-a (get-buffer-create "*pred-a*"))
           (buf-b (get-buffer-create "*pred-b*"))
           (buf-side (get-buffer-create "*pred-side*"))
           (w-side (display-buffer-in-side-window buf-side '((side . right))))
           (w-dead (split-window w2 nil 'right))
           (w-mini (minibuffer-window)))
      (delete-window w-dead)
      (unwind-protect
          (progn
            (set-window-buffer w1 buf-a)
            (set-window-buffer w2 buf-b)

            ;; Normal non-selected window (w2)
            (expect (dp-window-utility-displayable-p w2 buf-a) :to-be-truthy)
            (expect (dp-window-utility-eligible-p w2 buf-a nil) :to-be-truthy)
            (expect (dp-window-utility-eligible-p w2 buf-a w1) :to-be-truthy)
            (expect (dp-window-utility-ineligible-reason w2 buf-a w1) :to-be nil)
            (expect (dp-window-utility-splittable-p w2) :to-be-truthy)
            (expect (dp-window-utility-cannot-display-p w2 buf-a) :to-be nil)

            ;; Normal selected window (w1): ineligible only when excluded by prefix
            (expect (dp-window-utility-displayable-p w1 buf-b) :to-be-truthy)
            (expect (dp-window-utility-eligible-p w1 buf-b nil) :to-be-truthy)
            (expect (dp-window-utility-eligible-p w1 buf-b w1) :to-be nil)
            (expect (dp-window-utility-ineligible-reason w1 buf-b w1)
                    :to-match "other-window-prefix")
            (expect (dp-window-utility-splittable-p w1) :to-be-truthy)

            ;; Hard-dedicated to *this* buffer vs *another* buffer
            (set-window-dedicated-p w2 t)
            (expect (dp-window-utility-displayable-p w2 buf-b) :to-be-truthy)
            (expect (dp-window-utility-displayable-p w2 (buffer-name buf-b))
                    :to-be-truthy)
            (expect (dp-window-utility-eligible-p w2 buf-b nil) :to-be-truthy)
            (expect (dp-window-utility-eligible-p w2 buf-b w2) :to-be nil)
            (expect (dp-window-utility-displayable-p w2 buf-a) :to-be nil)
            (expect (dp-window-utility-displayable-p w2 nil) :to-be nil)
            (expect (dp-window-utility-cannot-display-p w2 buf-b) :to-be nil)
            (expect (dp-window-utility-cannot-display-p w2 buf-a) :to-be-truthy)
            (expect (dp-window-utility-cannot-display-p w2) :to-be-truthy)
            (expect (dp-window-utility-eligible-p w2 buf-a nil) :to-be nil)
            (expect (dp-window-utility-ineligible-reason w2 buf-a nil)
                    :to-match "dedicated to \\*pred-b\\*")
            ;; Undisplayable dedicated normal window is STILL splittable!
            (expect (dp-window-utility-splittable-p w2) :to-be-truthy)

            ;; Soft-dedicated ('weak) follows the same per-buffer rule
            (set-window-dedicated-p w2 'weak)
            (expect (dp-window-utility-displayable-p w2 buf-b) :to-be-truthy)
            (expect (dp-window-utility-displayable-p w2 buf-a) :to-be nil)
            (expect (dp-window-utility-splittable-p w2) :to-be-truthy)
            (set-window-dedicated-p w2 nil)

            ;; Side window (even for its own buffer, dedicated or not)
            (expect (dp-window-utility-displayable-p w-side buf-side) :to-be nil)
            (expect (dp-window-utility-eligible-p w-side buf-side nil) :to-be nil)
            (expect (dp-window-utility-ineligible-reason w-side buf-side nil)
                    :to-match "side window")
            (expect (dp-window-utility-splittable-p w-side) :to-be nil)
            (set-window-dedicated-p w-side nil)
            (expect (dp-window-utility-displayable-p w-side buf-side) :to-be nil)
            (expect (dp-window-utility-splittable-p w-side) :to-be nil)

            ;; Minibuffer window
            (expect (dp-window-utility-displayable-p w-mini buf-a) :to-be nil)
            (expect (dp-window-utility-eligible-p w-mini buf-a nil) :to-be nil)
            (expect (dp-window-utility-ineligible-reason w-mini buf-a nil)
                    :to-match "minibuffer")
            (expect (dp-window-utility-splittable-p w-mini) :to-be nil)

            ;; Dead window, nil, and non-window values
            (dolist (bad (list w-dead nil 'not-a-window))
              (expect (dp-window-utility-displayable-p bad buf-a) :to-be nil)
              (expect (dp-window-utility-eligible-p bad buf-a nil) :to-be nil)
              (expect (dp-window-utility-ineligible-reason bad buf-a nil)
                      :to-match "live")
              (expect (dp-window-utility-splittable-p bad) :to-be nil))

            ;; Unsplittable frame: displayable and eligible, but not splittable
            (let ((orig-frame-param (symbol-function 'frame-parameter)))
              (cl-letf (((symbol-function 'frame-parameter)
                         (lambda (frame param)
                           (if (eq param 'unsplittable)
                               t
                             (funcall orig-frame-param frame param)))))
                (expect (dp-window-utility-displayable-p w1 buf-a)
                        :to-be-truthy)
                (expect (dp-window-utility-eligible-p w1 buf-a nil)
                        :to-be-truthy)
                (expect (dp-window-utility-splittable-p w1) :to-be nil)
                (expect (dp-window-utility-unsplittable-reason w1)
                        :to-equal "unsplittable frame")))

            ;; Exact reason strings matching DESIGN_RULESET.md Section 2 reference table
            (expect (dp-window-utility-unsplittable-reason w1) :to-be nil)
            (expect (dp-window-utility-unsplittable-reason w-side)
                    :to-equal "side window")
            (expect (dp-window-utility-unsplittable-reason w-mini)
                    :to-equal "minibuffer window")
            (expect (dp-window-utility-unsplittable-reason w-dead)
                    :to-equal "window is no longer live")
            (expect (dp-window-utility-unsplittable-reason nil)
                    :to-equal "window is no longer live")
            (expect (dp-window-utility-ineligible-reason w-dead buf-a nil)
                    :to-equal "window is no longer live")
            (expect (dp-window-utility-ineligible-reason w-mini buf-a nil)
                    :to-equal "minibuffer window")
            (expect (dp-window-utility-ineligible-reason w-side buf-side nil)
                    :to-equal "side window")
            (set-window-dedicated-p w2 t)
            (expect (dp-window-utility-ineligible-reason w2 buf-a nil)
                    :to-equal "dedicated to *pred-b*")
            (expect (dp-window-utility-unsplittable-reason w2) :to-be nil)
            (set-window-dedicated-p w2 nil)
            (expect (dp-window-utility-ineligible-reason w1 buf-b w1)
                    :to-equal "excluded by other-window-prefix"))
        (when (window-live-p w-side) (delete-window w-side))
        (when (window-live-p w2)
          (set-window-dedicated-p w2 nil)
          (delete-window w2))
        (kill-buffer buf-a)
        (kill-buffer buf-b)
        (kill-buffer buf-side))))

  (it "treats a window dedicated to the displayed buffer as displayable in prefix commands"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (pop-up-windows nil)
           (dp-window-utility-split-maximum 0)
           (w1 (selected-window))
           (w2 (split-window w1 nil 'below))
           (buf (get-buffer-create "*pred-prefix-self*"))
           (ask-calls 0))
      (set-window-buffer w2 buf)
      (set-window-dedicated-p w2 t)
      (unwind-protect
          (progn
            ;; other-window-prefix accepts w2 dedicated to buf itself on first pick.
            (select-window w1)
            (dp-other-window-prefix)
            (cl-letf (((symbol-function 'display-buffer-pop-up-window)
                       (lambda (&rest _) nil))
                      ((symbol-function 'dp-window-utility--read-key-vector)
                       (lambda (&rest _)
                         (setq ask-calls (1+ ask-calls))
                         [?2])))
              (expect (display-buffer buf) :to-be w2)
              (expect ask-calls :to-be 1))
            ;; same-window-prefix keeps w2 when selected and dedicated to buf itself.
            (select-window w2)
            (dp-same-window-prefix)
            (expect (display-buffer buf) :to-be w2)
            (expect (window-dedicated-p w2) :to-be-truthy))
        (setq display-buffer-overriding-action '(nil . nil))
        (when (window-live-p w2)
          (set-window-dedicated-p w2 nil)
          (delete-window w2))
        (kill-buffer buf)))))

(describe "disbuf-pivot cannot-prompt context guards"
  (it "allows prompting in normal interactive context and blocks batch, minibuffer, kbd macro, and async contexts"
    (let ((noninteractive nil)
          (executing-kbd-macro nil)
          (inhibit-quit nil)
          (dp-window-utility--in-prompt nil)
          (dp-tab-bar--in-progress nil))
      (expect (dp-window-utility-cannot-prompt-p) :to-be nil)

      ;; Batch
      (let ((noninteractive t))
        (expect (dp-window-utility-cannot-prompt-p) :to-be-truthy))

      ;; Active minibuffer
      (cl-letf (((symbol-function 'active-minibuffer-window)
                 (lambda () (minibuffer-window))))
        (expect (dp-window-utility-cannot-prompt-p) :to-be-truthy))

      ;; Keyboard macro
      (let ((executing-kbd-macro [?a]))
        (expect (dp-window-utility-cannot-prompt-p) :to-be-truthy))

      ;; Inhibit-quit and waiting for user input (async callbacks)
      (let ((inhibit-quit t))
        (expect (dp-window-utility-cannot-prompt-p) :to-be-truthy))
      (cl-letf (((symbol-function 'waiting-for-user-input-p) (lambda () t)))
        (expect (dp-window-utility-cannot-prompt-p) :to-be-truthy))

      ;; Open prompt or tab/consult preview in progress
      (let ((dp-window-utility--in-prompt t))
        (expect (dp-window-utility-cannot-prompt-p) :to-be-truthy))
      (let ((dp-tab-bar--in-progress t))
        (expect (dp-window-utility-cannot-prompt-p) :to-be-truthy))))

  (it "returns nil from display, tab, frame, and window prompts in cannot-prompt contexts without walking the stack"
    (let ((buf (get-buffer-create "*cannot-prompt*"))
          (orig-current-action (symbol-function 'dp-action--current-action))
          (orig-mapbacktrace (symbol-function 'mapbacktrace))
          (prompted 0)
          (action-lookups 0)
          (backtrace-walks 0))
      (dp-action-mode +1)
      (unwind-protect
          (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                     (lambda (&rest _) (setq prompted (1+ prompted)) [?1]))
                    ((symbol-function 'completing-read)
                     (lambda (&rest _) (setq prompted (1+ prompted)) ""))
                    ((symbol-function 'dp-action--current-action)
                     (lambda ()
                       (setq action-lookups (1+ action-lookups))
                       (funcall orig-current-action)))
                    ((symbol-function 'mapbacktrace)
                     (lambda (&rest args)
                       (setq backtrace-walks (1+ backtrace-walks))
                       (apply orig-mapbacktrace args))))
            (dolist (ctx '(batch minibuf kbd-macro recursive-prompt
                           recursive-tab inhibit-quit waiting-input))
              (let ((noninteractive (eq ctx 'batch))
                    (executing-kbd-macro (and (eq ctx 'kbd-macro) [?x]))
                    (dp-window-utility--in-prompt (eq ctx 'recursive-prompt))
                    (dp-tab-bar--in-progress (eq ctx 'recursive-tab))
                    (inhibit-quit (eq ctx 'inhibit-quit)))
                (cl-letf (((symbol-function 'active-minibuffer-window)
                           (lambda () (and (eq ctx 'minibuf) (minibuffer-window))))
                          ((symbol-function 'waiting-for-user-input-p)
                           (lambda () (eq ctx 'waiting-input))))
                  (expect (dp-action--display buf nil) :to-be nil)
                  (expect (window-live-p (display-buffer buf)) :to-be-truthy)
                  (expect (dp-action-tab buf nil) :to-be nil)
                  (expect (dp-action--frame buf nil) :to-be nil)
                  (expect (dp-window-utility-choose-display-window 'frame nil nil buf)
                          :to-be nil)
                  (expect (dp-window-utility-choose-tab-window nil buf)
                          :to-be nil))))
            (expect prompted :to-be 0)
            (expect action-lookups :to-be 0)
            (expect backtrace-walks :to-be 0))
        (dp-action-mode -1)
        (kill-buffer buf))))

  (it "blocks prompting inside timers (with and without with-local-quit)"
    (let ((noninteractive nil)
          (regular-blocked nil)
          (local-quit-blocked nil)
          (display-returned 'unset)
          (action-lookups 0)
          (orig-current-action (symbol-function 'dp-action--current-action))
          (buf (get-buffer-create "*timer-guard*")))
      (unwind-protect
          (cl-letf (((symbol-function 'dp-action--current-action)
                     (lambda ()
                       (setq action-lookups (1+ action-lookups))
                       (funcall orig-current-action))))
            (run-at-time
             0 nil
             (lambda ()
               (setq regular-blocked (dp-window-utility-cannot-prompt-p))
               (with-local-quit
                 (setq local-quit-blocked (dp-window-utility-cannot-prompt-p))
                 (setq display-returned (dp-action--display buf nil)))))
            (accept-process-output nil 0.1)
            (expect regular-blocked :to-be-truthy)
            (expect local-quit-blocked :to-be-truthy)
            (expect display-returned :to-be nil)
            (expect action-lookups :to-be 0))
        (kill-buffer buf))))

  (it "blocks prompting inside process filters and sentinels (even with with-local-quit)"
    (let ((noninteractive nil)
          (filter-blocked nil)
          (filter-local-quit-blocked nil)
          (sentinel-blocked nil)
          (filter-display 'unset)
          (action-lookups 0)
          (orig-current-action (symbol-function 'dp-action--current-action))
          (buf (get-buffer-create "*proc-guard*")))
      (unwind-protect
          (cl-letf (((symbol-function 'dp-action--current-action)
                     (lambda ()
                       (setq action-lookups (1+ action-lookups))
                       (funcall orig-current-action))))
            (let ((proc
                   (make-process
                    :name "dp-guard-test"
                    :command (list "echo" "ok")
                    :filter (lambda (_p _out)
                              (setq filter-blocked (dp-window-utility-cannot-prompt-p))
                              (with-local-quit
                                (setq filter-local-quit-blocked
                                      (dp-window-utility-cannot-prompt-p))
                                (setq filter-display (dp-action--display buf nil))))
                    :sentinel (lambda (_p _ev)
                                (setq sentinel-blocked
                                      (dp-window-utility-cannot-prompt-p))))))
              (while (process-live-p proc)
                (accept-process-output proc 0.1))
              (accept-process-output nil 0.05)
              (expect filter-blocked :to-be-truthy)
              (expect filter-local-quit-blocked :to-be-truthy)
              (expect filter-display :to-be nil)
              (expect sentinel-blocked :to-be-truthy))
            ;; Synchronous sentinel triggered via delete-process with with-local-quit
            (let* ((del-blocked nil)
                   (del-local-quit-blocked nil)
                   (del-display 'unset)
                   (proc (make-process
                          :name "dp-del-guard-test"
                          :command (list "sleep" "5")
                          :sentinel (lambda (_p _ev)
                                      (setq del-blocked
                                            (dp-window-utility-cannot-prompt-p))
                                      (with-local-quit
                                        (setq del-local-quit-blocked
                                              (dp-window-utility-cannot-prompt-p))
                                        (setq del-display
                                              (dp-action--display buf nil)))))))
              (delete-process proc)
              (expect del-blocked :to-be-truthy)
              (expect del-local-quit-blocked :to-be-truthy)
              (expect del-display :to-be nil))
            (expect action-lookups :to-be 0))
        (kill-buffer buf))))

  (it "guards recursive display during tab creation, frame creation, and window prompt"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (w2 (split-window w1 nil 'below))
           (buf (get-buffer-create "*rec-outer*"))
           (nested (get-buffer-create "*rec-nested*"))
           (tab-nested-res 'unset)
           (frame-nested-res 'unset)
           (prompt-nested-res 'unset))
      (unwind-protect
          (progn
            ;; Recursive display during tab creation
            (cl-letf (((symbol-function 'tab-bar-tabs)
                       (lambda () '(((name . "one") (index . 0)))))
                      ((symbol-function 'tab-bar-new-tab)
                       (lambda (&rest _)
                         (setq tab-nested-res (dp-action--display nested nil))))
                      ((symbol-function 'tab-bar-rename-tab) #'ignore)
                      ((symbol-function 'tab-bar-change-tab-group) #'ignore)
                      ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
                      ((symbol-function 'dp-window-utility-dispatch-prompt)
                       (lambda (_b a &rest _)
                         (list :action 'window :window w2 :alist a))))
              (dp-action-tab buf '((tab-name . "fresh-tab")))
              (expect tab-nested-res :to-be nil))

            ;; Recursive display during frame creation
            (cl-letf (((symbol-function 'dp-action--frames) (lambda (&rest _) nil))
                      ((symbol-function 'completing-read) (lambda (&rest _) ""))
                      ((symbol-function 'display-buffer-pop-up-frame)
                       (lambda (_b _a)
                         (setq frame-nested-res (dp-action--display nested nil))
                         w2)))
              (dp-action--frame buf '((pop-up-frames . t)))
              (expect frame-nested-res :to-be nil))

            ;; Recursive display during open dispatch prompt
            (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                       (lambda (&rest _)
                         (setq prompt-nested-res (dp-action--display nested nil))
                         [?2])))
              (dp-window-utility-choose-display-window 'frame nil nil buf)
              (expect prompt-nested-res :to-be nil)))
        (when (window-live-p w2) (delete-window w2))
        (kill-buffer buf)
        (kill-buffer nested)))))

(describe "disbuf-pivot dp-action--action reentrancy"
  (it "delivers the caller's ACTION once per call without mutating display-buffer-alist"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (buf (get-buffer-create "*reent-basic*"))
           (expected-action '(nil (category . basic)))
           (orig-current-action (symbol-function 'dp-action--current-action))
           (orig-mapbacktrace (symbol-function 'mapbacktrace))
           (action-lookups 0)
           (backtrace-walks 0)
           (seen-action 'unset)
           (seen-during-override 'unset))
      (dp-action-mode +1)
      (unwind-protect
          (let* ((entry (assq 'dp-action-control-p display-buffer-alist))
                 (orig-cdr (cdr entry)))
            (cl-letf (((symbol-function 'dp-action--current-action)
                       (lambda ()
                         (setq action-lookups (1+ action-lookups))
                         (funcall orig-current-action)))
                      ((symbol-function 'mapbacktrace)
                       (lambda (&rest args)
                         (setq backtrace-walks (1+ backtrace-walks))
                         (apply orig-mapbacktrace args)))
                      ((symbol-function 'dp-action--run)
                       (lambda (_b _a)
                         (setq seen-action dp-action--action)
                         w1)))
              (expect (display-buffer buf expected-action) :to-be w1))
            (expect seen-action :to-equal expected-action)
            (expect action-lookups :to-be 1)
            ;; 1 walk for async guard + 1 walk for stack-caller-action (no double lookup).
            (expect backtrace-walks :to-be 2)
            (expect (cdr entry) :to-be orig-cdr)
            (expect (cdr entry) :to-equal '(dp-action--display))

            ;; Overriding action can read the caller's ACTION directly and
            ;; leaves display-buffer-alist untouched.
            (let ((display-buffer-overriding-action
                   (list (lambda (_b _a)
                           (setq seen-during-override (dp-action--current-action))
                           w1))))
              (display-buffer buf expected-action))
            (expect seen-during-override :to-equal expected-action)
            (expect (cdr entry) :to-be orig-cdr)

            ;; Invalid-buffer error also leaves display-buffer-alist untouched.
            (expect (display-buffer "*does-not-exist-reent*" expected-action)
                    :to-throw 'error)
            (expect (cdr entry) :to-be orig-cdr))
        (dp-action-mode -1)
        (kill-buffer buf))))

  (it "works with compound conditions, quoted display-buffer-alist entries, custom alists, and advised display-buffer"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (buf (get-buffer-create "*reent-compound*"))
           (action-in '((display-buffer-in-tab) (category . compound)))
           (action-adv '((display-buffer-in-new-tab) (category . advised)))
           (seen-action 'unset)
           (seen-alist nil))
      (unwind-protect
          (progn
            ;; Compound condition with direct dp-action--display and extra alist entry
            (let ((display-buffer-alist
                   '(((and (not "\\*skip\\*") dp-action-control-p)
                      dp-action--display
                      (custom-entry . preserved)))))
              (cl-letf (((symbol-function 'dp-action-tab)
                         (lambda (_b alist)
                           (setq seen-action dp-action--action
                                 seen-alist alist)
                           (cons w1 'reuse))))
                (expect (display-buffer buf action-in) :to-be w1))
              (expect seen-action :to-equal action-in)
              (expect (alist-get 'custom-entry seen-alist) :to-be 'preserved)
              (expect (cdar display-buffer-alist)
                      :to-equal '(dp-action--display (custom-entry . preserved))))

            ;; Advice transforming ACTION on display-buffer delivers transformed ACTION
            (let ((adv (lambda (fn b &optional _a f)
                         (funcall fn b action-adv f))))
              (dp-action-mode +1)
              (advice-add 'display-buffer :around adv)
              (unwind-protect
                  (cl-letf (((symbol-function 'dp-action-tab)
                             (lambda (_b _a)
                               (setq seen-action dp-action--action)
                               (cons w1 'tab))))
                    (expect (display-buffer buf action-in) :to-be w1)
                    (expect seen-action :to-equal action-adv))
                (advice-remove 'display-buffer adv)
                (dp-action-mode -1))))
        (kill-buffer buf))))

  (it "does not clobber outer ACTION on nested display-buffer inside overriding action (different or same buffer)"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (buf1 (get-buffer-create "*reent-outer*"))
           (buf2 (get-buffer-create "*reent-inner*"))
           (action-outer '((display-buffer-in-tab) (category . outer)))
           (action-inner '((display-buffer-pop-up-frame) (category . inner)))
           (seen nil)
           (in-override nil))
      (dp-action-mode +1)
      (unwind-protect
          (progn
            ;; Case 1: different buffer nested inside display-buffer-overriding-action
            (setq in-override nil)
            (let ((display-buffer-overriding-action
                   (list
                    (lambda (_b _a)
                      (unless in-override
                        (setq in-override t)
                        (unwind-protect
                            (display-buffer buf2 action-inner)
                          (setq in-override nil)))
                      nil))))
              (cl-letf (((symbol-function 'dp-action-tab)
                         (lambda (b _a)
                           (push (list 'tab (buffer-name b) dp-action--action) seen)
                           (cons w1 'reuse)))
                        ((symbol-function 'dp-action--frame)
                         (lambda (b _a)
                           (push (list 'frame (buffer-name b) dp-action--action) seen)
                           w1))
                        ((symbol-function 'dp-action--run)
                         (lambda (b _a)
                           (push (list 'run (buffer-name b) dp-action--action) seen)
                           w1)))
                (expect (display-buffer buf1 action-outer) :to-be w1)))
            (expect (nreverse seen)
                    :to-equal (list (list 'frame "*reent-inner*" action-inner)
                                    (list 'tab "*reent-outer*" action-outer)))

            ;; Case 2: SAME buffer nested inside display-buffer-overriding-action
            (setq seen nil
                  in-override nil)
            (let ((display-buffer-overriding-action
                   (list
                    (lambda (_b _a)
                      (unless in-override
                        (setq in-override t)
                        (unwind-protect
                            (display-buffer buf1 action-inner)
                          (setq in-override nil)))
                      nil))))
              (cl-letf (((symbol-function 'dp-action-tab)
                         (lambda (b _a)
                           (push (list 'tab (buffer-name b) dp-action--action) seen)
                           (cons w1 'reuse)))
                        ((symbol-function 'dp-action--frame)
                         (lambda (b _a)
                           (push (list 'frame (buffer-name b) dp-action--action) seen)
                           w1))
                        ((symbol-function 'dp-action--run)
                         (lambda (b _a)
                           (push (list 'run (buffer-name b) dp-action--action) seen)
                           w1)))
                (expect (display-buffer buf1 action-outer) :to-be w1)))
            (expect (nreverse seen)
                    :to-equal (list (list 'frame "*reent-outer*" action-inner)
                                    (list 'tab "*reent-outer*" action-outer)))

            ;; Case 3: excluded buffer nested inside display-buffer-overriding-action
            (setq seen nil
                  in-override nil)
            (let* ((dp-exclude-conditions '("\\*reent-inner\\*"))
                   (action-excl '((display-buffer-same-window) (category . excl)))
                   (display-buffer-overriding-action
                    (list
                     (lambda (_b _a)
                       (unless in-override
                         (setq in-override t)
                         (unwind-protect
                             (display-buffer buf2 action-excl)
                           (setq in-override nil)))
                       nil))))
              (cl-letf (((symbol-function 'dp-action-tab)
                         (lambda (b _a)
                           (push (list 'tab (buffer-name b) dp-action--action) seen)
                           (cons w1 'reuse)))
                        ((symbol-function 'dp-action--frame)
                         (lambda (b _a)
                           (push (list 'frame (buffer-name b) dp-action--action) seen)
                           w1))
                        ((symbol-function 'dp-action--run)
                         (lambda (b _a)
                           (push (list 'run (buffer-name b) dp-action--action) seen)
                           w1)))
                (expect (display-buffer buf1 action-outer) :to-be w1)))
            (expect seen
                    :to-equal (list (list 'tab "*reent-outer*" action-outer))))
        (dp-action-mode -1)
        (kill-buffer buf1)
        (kill-buffer buf2))))

  (it "remains clean when overriding action handles or errors and preserves outer ACTION on inner dp-action--display"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (buf1 (get-buffer-create "*reent-err1*"))
           (buf2 (get-buffer-create "*reent-err2*"))
           (a1 '((display-buffer-in-tab) (category . one)))
           (a2 '(nil (category . two)))
           (a3 '(nil (category . three)))
           (seen nil))
      (dp-action-mode +1)
      (unwind-protect
          (progn
            ;; Overriding action handles buf1 directly (outer dispatcher never runs)
            (let ((display-buffer-overriding-action (list (lambda (_b _a) w1))))
              (display-buffer buf1 a1))
            ;; No circular references in display-buffer-alist even before reset
            (let ((print-circle nil))
              (expect (stringp (prin1-to-string display-buffer-alist))
                      :to-be-truthy))
            ;; Overriding action signals error
            (let ((display-buffer-overriding-action
                   (list (lambda (_b _a) (error "boom")))))
              (expect (display-buffer buf1 a1) :to-throw 'error))
            ;; Next normal call sees a2, not stale a1
            (cl-letf (((symbol-function 'dp-action--run)
                       (lambda (_b _a)
                         (setq seen dp-action--action)
                         w1)))
              (expect (display-buffer buf2 a2) :to-be w1)
              (expect seen :to-equal a2))
            ;; Nested display-buffer inside real dp-action--display itself
            ;; (both non-nil ACTION and nil ACTION without leaking outer a1).
            (let ((trace nil))
              (cl-letf (((symbol-function 'dp-action-tab)
                         (lambda (b _a)
                           (push (list 'enter (buffer-name b) dp-action--action) trace)
                           (display-buffer buf2 a3)
                           (display-buffer buf2)
                           (push (list 'exit (buffer-name b) dp-action--action) trace)
                           (cons w1 'reuse)))
                        ((symbol-function 'dp-action--run)
                         (lambda (b _a)
                           (push (list 'enter (buffer-name b) dp-action--action) trace)
                           (push (list 'exit (buffer-name b) dp-action--action) trace)
                           w1)))
                (expect (display-buffer buf1 a1) :to-be w1))
              (expect (nreverse trace)
                      :to-equal (list (list 'enter "*reent-err1*" a1)
                                      (list 'enter "*reent-err2*" a3)
                                      (list 'exit "*reent-err2*" a3)
                                      (list 'enter "*reent-err2*" nil)
                                      (list 'exit "*reent-err2*" nil)
                                      (list 'exit "*reent-err1*" a1)))))
        (dp-action-mode -1)
        (kill-buffer buf1)
        (kill-buffer buf2)))))

(describe "disbuf-pivot exclude conditions"
  (it "excludes buffers matching regexp, derived-mode, major-mode, category, this-command, predicate, and boolean combinators"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (w2 (split-window w1 nil 'below))
           (buf-el (get-buffer-create "*excl-el*"))
           (buf-txt (get-buffer-create "*excl-txt*"))
           (later-hits 0)
           (dp-hits 0))
      (with-current-buffer buf-el (emacs-lisp-mode))
      (with-current-buffer buf-txt (text-mode))
      (dp-action-mode +1)
      (unwind-protect
          (let ((display-buffer-alist
                 (append display-buffer-alist
                         (list (cons (lambda (_b _a) t)
                                     (list (lambda (b _a)
                                             (setq later-hits (1+ later-hits))
                                             (set-window-buffer w2 b)
                                             w2)))))))
            (cl-letf (((symbol-function 'dp-action--run)
                       (lambda (b _a)
                         (setq dp-hits (1+ dp-hits))
                         (set-window-buffer w1 b)
                         w1)))
              ;; Empty exclude conditions: package regulates
              (let ((dp-exclude-conditions nil))
                (expect (display-buffer buf-el) :to-be w1)
                (expect dp-hits :to-be 1)
                (expect later-hits :to-be 0))

              ;; Regexp match: skipped to later display-buffer-alist entry
              (let ((dp-exclude-conditions '("\\*excl-el\\*")))
                (expect (display-buffer buf-el) :to-be w2)
                (expect dp-hits :to-be 1)
                (expect later-hits :to-be 1)
                ;; Non-matching buffer still regulated
                (expect (display-buffer buf-txt) :to-be w1)
                (expect dp-hits :to-be 2))

              ;; derived-mode
              (let ((dp-exclude-conditions '((derived-mode . prog-mode))))
                (expect (display-buffer buf-el) :to-be w2)
                (expect (display-buffer buf-txt) :to-be w1))

              ;; major-mode (exact only)
              (let ((dp-exclude-conditions '((major-mode . prog-mode))))
                (expect (display-buffer buf-el) :to-be w1))
              (let ((dp-exclude-conditions '((major-mode . emacs-lisp-mode))))
                (expect (display-buffer buf-el) :to-be w2))

              ;; category (requires passing ACTION as 3rd arg to buffer-match-p)
              (let ((dp-exclude-conditions '((category . special-cat))))
                (expect (display-buffer buf-txt '(nil (category . special-cat)))
                        :to-be w2)
                (expect (display-buffer buf-txt '(nil (category . other-cat)))
                        :to-be w1)
                (expect (display-buffer buf-txt) :to-be w1))

              ;; this-command (symbol and list)
              (let ((dp-exclude-conditions '((this-command . my-special-cmd)))
                    (this-command 'my-special-cmd))
                (expect (display-buffer buf-txt) :to-be w2))
              (let ((dp-exclude-conditions '((this-command cmd-a cmd-b)))
                    (this-command 'cmd-b))
                (expect (display-buffer buf-txt) :to-be w2))
              (let ((dp-exclude-conditions '((this-command . my-special-cmd)))
                    (this-command 'other-cmd))
                (expect (display-buffer buf-txt) :to-be w1))

              ;; Predicate function receiving buffer and ACTION
              (let ((dp-exclude-conditions
                     (list (lambda (b a)
                             (and (equal b "*excl-txt*")
                                  (eq (alist-get 'custom-flag (cdr a)) 'yes))))))
                (expect (display-buffer buf-txt '(nil (custom-flag . yes)))
                        :to-be w2)
                (expect (display-buffer buf-txt '(nil (custom-flag . no)))
                        :to-be w1))

              ;; Boolean combinators (and / or / not)
              (let ((dp-exclude-conditions
                     '((and (derived-mode . prog-mode)
                            (not "\\*keep\\*")))))
                (expect (display-buffer buf-el) :to-be w2)
                (expect (display-buffer buf-txt) :to-be w1))))
        (dp-action-mode -1)
        (when (window-live-p w2) (delete-window w2))
        (kill-buffer buf-el)
        (kill-buffer buf-txt))))

  (it "handles nonexistent buffers, non-list, improper-list, and circular ACTION safely"
    (let ((dp-exclude-conditions
           '((derived-mode . prog-mode)
             (major-mode . emacs-lisp-mode)
             (category . my-cat)))
          (buf (get-buffer-create "*excl-edge*"))
          (circular (cons '(display-buffer-same-window) nil)))
      (setcdr circular circular)
      (unwind-protect
          (progn
            (expect (dp-action-control-p "*does-not-exist-anywhere*" nil)
                    :to-be-truthy)
            (expect (dp-action-control-p buf t) :to-be-truthy)
            (expect (dp-action-control-p buf '(display-buffer-same-window . bad))
                    :to-be-truthy)
            (expect (dp-action-control-p
                     buf '((display-buffer-same-window) (a . 1) . bad))
                    :to-be-truthy)
            (expect (dp-action-control-p buf circular) :to-be-truthy)
            ;; Improper function list inside ACTION does not error in target check.
            (let ((dp-action--action '((display-buffer-same-window . bad))))
              (expect (dp-action--functions dp-action--action) :to-be nil)
              (expect (dp-action--target nil) :to-be nil))
            ;; Stack caller-action lookup normalizes improper/circular ACTION to nil.
            (let ((seen-improper 'unset)
                  (seen-circular 'unset))
              (cl-letf (((symbol-function 'display-buffer)
                         (lambda (_b _a)
                           (dp-action--stack-caller-action))))
                (setq seen-improper
                      (display-buffer buf '((display-buffer-same-window) (a . 1) . bad))
                      seen-circular
                      (display-buffer buf circular)))
              (expect seen-improper :to-equal '(t))
              (expect seen-circular :to-equal '(t)))
            (dp-action-mode +1)
            (unwind-protect
                (expect (display-buffer "*does-not-exist-anywhere*")
                        :to-throw 'error)
              (dp-action-mode -1)))
        (setcdr circular nil)
        (kill-buffer buf)))))

(provide 'core-test)

;; Local Variables:
;; read-symbol-shorthands: (("dp-" . "disbuf-pivot-"))
;; End:

;;; core-test.el ends here
