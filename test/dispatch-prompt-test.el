;;; dispatch-prompt-test.el --- Buttercup tests for Milestone 2 dispatch prompt  -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for Section 5 of `docs/DESIGN_RULESET.md': window-label key
;; generation and uniform fixed-width overflow, key precedence and
;; collision resolution, window-label overlays, direct
;; `display-buffer-in-side-window' menu creation, header info and
;; dispatch prompt default, responsive 3/2/1 logical column wrapping,
;; other-window scrolling without changing `selected-window',
;; small-frame echo-area fallback, split actions and split-target read,
;; `M-0'..`M-6' window-setting toggles with `(KEY . nil)' shadowing,
;; `C-g' abort, `"Bypass pivot"` (`M-b`), `"Leave undisplayed"` (`M-n`),
;; and `"Use caller intent"` (`M-c`).

;;; Code:

(require 'buttercup)
(require 'cl-lib)
(require 'disbuf-pivot)
(require 'dp-window-utility)

(describe "disbuf-pivot window-label key generation"
  (it "generates decimal 1..9 and zero-padded 01..99 / 001..999 overflow"
    (expect (dp-window-utility--generate-window-labels 3)
            :to-equal '("1" "2" "3"))
    (expect (dp-window-utility--generate-window-labels 9)
            :to-equal '("1" "2" "3" "4" "5" "6" "7" "8" "9"))
    (expect (dp-window-utility--generate-window-labels 12)
            :to-equal '("01" "02" "03" "04" "05" "06" "07" "08" "09"
                        "10" "11" "12"))
    (let ((hundred (dp-window-utility--generate-window-labels 100)))
      (expect (length hundred) :to-be 100)
      (expect (car hundred) :to-equal "001")
      (expect (car (last hundred)) :to-equal "100"))
    ;; 0-based decimal digits
    (expect (dp-window-utility--generate-window-labels
             10 '(?0 ?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9))
            :to-equal '("0" "1" "2" "3" "4" "5" "6" "7" "8" "9"))
    (expect (dp-window-utility--generate-window-labels
             12 '(?0 ?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9))
            :to-equal '("00" "01" "02" "03" "04" "05" "06" "07" "08" "09"
                        "10" "11")))

  (it "avoids 0 in decimal overflow when ?0 is taken by a split action"
    (let ((labels (dp-window-utility--generate-window-labels
                   10 '(?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9)
                   '((?0 split-window-below "Split zero")))))
      (expect (length labels) :to-be 10)
      (expect (cl-some (lambda (l) (string-match-p "0" l)) labels) :to-be nil)
      (expect (car labels) :to-equal "11")))

  (it "skips split keys, deduplicates, and uses uniform base-K overflow for custom lists"
    ;; Home row with default splits b/r/f skips ?f -> 8 usable keys
    (expect (dp-window-utility--generate-window-labels
             8 '(?a ?s ?d ?f ?g ?h ?j ?k ?l))
            :to-equal '("a" "s" "d" "g" "h" "j" "k" "l"))
    (expect (dp-window-utility--generate-window-labels
             12 '(?a ?s ?d ?f ?g ?h ?j ?k ?l))
            :to-equal '("aa" "as" "ad" "ag" "ah" "aj" "ak" "al"
                        "sa" "ss" "sd" "sg"))
    ;; Duplicates removed in order; small custom list overflows uniformly
    (expect (dp-window-utility--generate-window-labels
             6 '(?a ?a ?s ?d ?g ?s))
            :to-equal '("aa" "as" "ad" "ag" "sa" "ss"))
    ;; Mixed list works identically
    (expect (dp-window-utility--generate-window-labels
             8 '(?a ?s ?d ?\; ?1 ?2))
            :to-equal '("aa" "as" "ad" "a;" "a1" "a2" "sa" "ss")))

  (it "warns and falls back to digits 1-9 when fewer than 2 usable keys remain for >1 windows"
    (let ((msgs nil))
      (cl-letf (((symbol-function 'message)
                 (lambda (fmt &rest args)
                   (push (apply #'format fmt args) msgs))))
        (expect (dp-window-utility--generate-window-labels 3 '(?a))
                :to-equal '("1" "2" "3"))
        (expect (dp-window-utility--generate-window-labels 3 '(?b ?r))
                :to-equal '("1" "2" "3"))
        (expect (length msgs) :to-be 2)
        ;; 1 usable key IS sufficient for 1 window (no warning)
        (setq msgs nil)
        (expect (dp-window-utility--generate-window-labels 1 '(?a))
                :to-equal '("a"))
        (expect msgs :to-be nil)))))

(describe "disbuf-pivot key allocation and collision rules"
  (it "resolves Meta-letter and Meta-digit collisions with C-M- fallback when exhausted"
    ;; Free preferred key wins
    (expect (dp-window-utility--allocate-key 'letter ?c nil)
            :to-be (dp-window-utility--meta-event ?c))
    ;; Taken M-c falls back to next free Meta-letter (skipping M-v first)
    (let ((ev (dp-window-utility--allocate-key
               'letter ?c (list (dp-window-utility--meta-event ?c)))))
      (expect ev :to-be (dp-window-utility--meta-event ?a)))
    ;; All M-a..M-z taken -> falls back to C-M-letter
    (let* ((all-meta (mapcar #'dp-window-utility--meta-event
                             (number-sequence ?a ?z)))
           (ev (dp-window-utility--allocate-key 'letter ?c all-meta)))
      (expect ev :to-be (dp-window-utility--ctrl-meta-event ?c)))
    ;; Taken M-1 prefers spare Meta-digits (M-7) before other digits
    (let ((ev (dp-window-utility--allocate-key
               'digit ?1 (list (dp-window-utility--meta-event ?1)))))
      (expect ev :to-be (dp-window-utility--meta-event ?7)))
    ;; All M-0..M-9 taken -> falls back to C-M-digit
    (let* ((all-meta-digits (mapcar #'dp-window-utility--meta-event
                                    (number-sequence ?0 ?9)))
           (ev (dp-window-utility--allocate-key 'digit ?1 all-meta-digits)))
      (expect ev :to-be (dp-window-utility--ctrl-meta-event ?1)))))

(describe "disbuf-pivot window-setting toggles and shadowing"
  (it "initializes present toggles in fixed order and shadows disabled keys with (KEY . nil)"
    (let* ((orig (list (cons 'window-height 20)
                       (cons 'dedicated t)
                       (cons 'body-function #'ignore)
                       (cons 'inhibit-switch-frame t)))
           (orig-copy (copy-tree orig))
           (toggles (dp-window-utility--init-toggles
                     orig '((dedicated . "base action")))))
      ;; Fixed order: dedicated (M-1) before window-height (M-4)
      (expect (mapcar (lambda (x) (plist-get x :key)) toggles)
              :to-equal '(dedicated window-height))
      (expect (mapcar (lambda (x) (plist-get x :digit)) toggles)
              :to-equal '(?1 ?4))
      (expect (plist-get (nth 0 toggles) :source) :to-equal "base action")
      (expect (plist-get (nth 1 toggles) :source) :to-be nil)
      (expect (dp-window-utility--toggles-all-state toggles) :to-be 'on)
      ;; Toggle dedicated off -> mixed, prepends (dedicated . nil) without mutating orig
      (dp-window-utility--toggle-entry toggles 'dedicated)
      (expect (dp-window-utility--toggles-all-state toggles) :to-be 'mixed)
      (let ((eff (dp-window-utility--effective-alist orig toggles)))
        (expect (assq 'dedicated eff) :to-equal '(dedicated . nil))
        (expect (alist-get 'dedicated eff) :to-be nil)
        (expect (alist-get 'window-height eff) :to-be 20)
        (expect (alist-get 'body-function eff) :to-be #'ignore)
        (expect (alist-get 'inhibit-switch-frame eff) :to-be t)
        (expect orig :to-equal orig-copy))
      ;; M-0 on mixed -> turns all off
      (dp-window-utility--toggle-all toggles)
      (expect (dp-window-utility--toggles-all-state toggles) :to-be 'off)
      (let ((eff (dp-window-utility--effective-alist orig toggles)))
        (expect (assq 'dedicated eff) :to-equal '(dedicated . nil))
        (expect (assq 'window-height eff) :to-equal '(window-height . nil)))
      ;; M-0 on off -> restores all to on
      (dp-window-utility--toggle-all toggles)
      (expect (dp-window-utility--toggles-all-state toggles) :to-be 'on)
      (let ((eff (dp-window-utility--effective-alist orig toggles)))
        (expect (alist-get 'dedicated eff) :to-be t)
        (expect (alist-get 'window-height eff) :to-be 20))))

  (it "shadows display-buffer-mark-dedicated when dedicated is toggled off on a split"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (display-buffer-mark-dedicated t)
           (buf (get-buffer-create "*toggle-ded*"))
           ;; M-1 turns dedicated off, then b splits sole window immediately.
           (keys (list (kbd "M-1") [?b]))
           new-win)
      (unwind-protect
          (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                     (lambda (&rest _) (pop keys))))
            (setq new-win (dp-action-choose-window buf '((dedicated . t))))
            (expect (window-live-p new-win) :to-be-truthy)
            ;; (dedicated . nil) shadow overrides display-buffer-mark-dedicated = t!
            (expect (window-dedicated-p new-win) :to-be nil))
        (when (window-live-p new-win) (delete-window new-win))
        (kill-buffer buf)))))

(describe "disbuf-pivot dispatch prompt menu rendering and header info"
  (it "controls header info with disbuf-pivot-header-info while always showing dispatch prompt default"
    (let ((info '(:caller-intent "Caller (xref-jump): direction right"
                  :source-entries ("base action: dedicated")
                  :window-facts ("selected window cannot display")))
          (default-str "[M-c] Use caller intent"))
      ;; t shows all three parts + default
      (let* ((dp-header-info t)
             (text (mapconcat #'identity
                              (dp-window-utility--format-header 80 info default-str)
                              "\n")))
        (expect text :to-match "Caller (xref-jump)")
        (expect text :to-match "base action: dedicated")
        (expect text :to-match "selected window cannot display")
        (expect text :to-match "Default: \\[M-c\\] Use caller intent"))
      ;; nil hides header info, keeps dispatch prompt default
      (let* ((dp-header-info nil)
             (text (mapconcat #'identity
                              (dp-window-utility--format-header 80 info default-str)
                              "\n")))
        (expect text :not :to-match "xref-jump")
        (expect text :not :to-match "base action")
        (expect text :not :to-match "selected window")
        (expect text :to-match "Default: \\[M-c\\] Use caller intent"))
      ;; subset list shows only requested parts + default
      (let* ((dp-header-info '(window-facts))
             (text (mapconcat #'identity
                              (dp-window-utility--format-header 80 info default-str)
                              "\n")))
        (expect text :not :to-match "xref-jump")
        (expect text :not :to-match "base action")
        (expect text :to-match "selected window cannot display")
        (expect text :to-match "Default: \\[M-c\\] Use caller intent"))))

  (it "renders responsive 3/2/1-column layouts with logical hanging-indent wrapping"
    (let* ((groups '(("Windows" "[1] very-long-buffer-name-example.el")
                     ("Dispatch actions" "Split" "  [b] Split below" "Other" "  [M-b] Bypass pivot")
                     ("Window settings" "[M-0] All (on)" "[M-1] dedicated (on, new windows only; base action)"))))
      ;; Wide (90 cols, min 20): 3 columns side by side (two " | " separators)
      (let ((rows-wide (dp-window-utility--layout-groups groups 90 20)))
        (expect rows-wide :to-be-truthy)
        (expect (car rows-wide) :to-match "Windows.* | .*Dispatch actions.* | .*Window settings")
        (dolist (row rows-wide)
          (expect (<= (string-width row) 90) :to-be-truthy)))
      ;; Medium (50 cols, min 20): 2 columns on top, Window settings underneath
      (let ((rows-med (dp-window-utility--layout-groups groups 50 20)))
        (expect rows-med :to-be-truthy)
        (expect (car rows-med) :to-match "Windows.* | .*Dispatch actions")
        (expect (car rows-med) :not :to-match "Window settings")
        (expect (cl-some (lambda (r) (string-match-p "Window settings" r)) rows-med)
                :to-be-truthy)
        (dolist (row rows-med)
          (expect (<= (string-width row) 50) :to-be-truthy)))
      ;; Narrow (25 cols, min 20): 1 stacked column with blank lines between groups
      (let ((rows-narrow (dp-window-utility--layout-groups groups 25 20)))
        (expect rows-narrow :to-be-truthy)
        (expect (car rows-narrow) :to-match "\\`Windows")
        (expect (cl-some (lambda (r) (string-empty-p r)) rows-narrow) :to-be-truthy)
        (expect (cl-some (lambda (r) (string-match-p "Dispatch actions" r)) rows-narrow)
                :to-be-truthy)
        (expect (cl-some (lambda (r) (string-match-p "Window settings" r)) rows-narrow)
                :to-be-truthy)
        (dolist (row rows-narrow)
          (expect (<= (string-width row) 25) :to-be-truthy)))
      ;; Below minimum width (15 < 20): returns nil -> triggers echo-area fallback
      (expect (dp-window-utility--layout-groups groups 15 20) :to-be nil))))

(describe "disbuf-pivot synchronous dispatch prompt interaction"
  (it "draws window-scoped overlays, opens menu directly via side window without intercept, and cleans up"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (shared-buf (get-buffer-create "*shared-ov*"))
           (side-buf (get-buffer-create "*bottom-comp*"))
           (target-buf (get-buffer-create "*target-disp*"))
           (w1 (selected-window))
           (w2 (split-window w1 nil 'below))
           (w-side (display-buffer-in-side-window side-buf '((side . bottom) (slot . 0))))
           (override-hits 0)
           (menu-seen nil)
           (sel-during-prompt nil)
           (ov-count-w1 0)
           (ov-count-w2 0)
           (ov-count-side 0)
           (menu-text nil))
      ;; Both w1 and w2 display the SAME buffer (empty buffer too!)
      (set-window-buffer w1 shared-buf)
      (set-window-buffer w2 shared-buf)
      (select-window w1)
      (unwind-protect
          (let ((display-buffer-overriding-action
                 (list (lambda (_b _a)
                         (setq override-hits (1+ override-hits))
                         w1))))
            (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                       (lambda (&rest _)
                         (setq sel-during-prompt (selected-window))
                         (let ((mbuf (get-buffer dp-window-utility--menu-buffer-name)))
                           (setq menu-seen (and mbuf (get-buffer-window mbuf)))
                           (when mbuf
                             (setq menu-text
                                   (with-current-buffer mbuf (buffer-string)))))
                         ;; Verify per-window overlays on shared-buf and side-buf
                         (with-current-buffer shared-buf
                           (dolist (ov (overlays-in (point-min) (point-max)))
                             (when (eq (overlay-get ov 'window) w1)
                               (setq ov-count-w1 (1+ ov-count-w1)))
                             (when (eq (overlay-get ov 'window) w2)
                               (setq ov-count-w2 (1+ ov-count-w2)))))
                         (with-current-buffer side-buf
                           (dolist (ov (overlays-in (point-min) (point-max)))
                             (when (eq (overlay-get ov 'window) w-side)
                               (setq ov-count-side (1+ ov-count-side)))))
                         [?2])))
              (let ((res (dp-window-utility-dispatch-prompt
                          target-buf '((dedicated . t)))))
                (expect (plist-get res :action) :to-be 'window)
                (expect (plist-get res :window) :to-be w2)))
            ;; Overriding action was NEVER called for the menu buffer
            (expect override-hits :to-be 0)
            ;; Selected window remained on w1 (never moved to menu)
            (expect sel-during-prompt :to-be w1)
            ;; Menu opened in a distinct side window without clobbering w-side
            (expect menu-seen :to-be-truthy)
            (expect (eq menu-seen w-side) :to-be nil)
            (expect (window-live-p w-side) :to-be-truthy)
            (expect (window-buffer w-side) :to-be side-buf)
            ;; M-0 All appears even with only 1 window-setting entry (dedicated)
            (expect menu-text :to-match "\\[M-0\\] All (on)")
            (expect menu-text :to-match "\\[M-1\\] dedicated (on, new windows only)")
            ;; Each window got its own window-scoped overlay
            (expect ov-count-w1 :to-be 1)
            (expect ov-count-w2 :to-be 1)
            (expect ov-count-side :to-be 1)
            ;; Overlays and menu buffer cleaned up after prompt returns
            (expect (get-buffer dp-window-utility--menu-buffer-name) :to-be nil)
            (with-current-buffer shared-buf
              (expect (overlays-in (point-min) (point-max)) :to-be nil)))
        (when (window-live-p w-side) (delete-window w-side))
        (when (window-live-p w2) (delete-window w2))
        (kill-buffer shared-buf)
        (kill-buffer side-buf)
        (kill-buffer target-buf))))

  (it "scrolls a tall menu via scroll-other-window without moving selected-window and leaves C-v/M-v unoccupied"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (buf (get-buffer-create "*scroll-test*"))
           ;; Create enough split actions to exceed side-window cap and force scrolling
           (dp-split-actions
            (cl-loop for ch in '(?a ?b ?c ?d ?e ?f ?g ?h ?i ?j ?k ?l ?m ?n ?o ?p ?q ?r)
                     collect (list ch #'split-window-below
                                   (format "Split action %c" ch))))
           (dp-menu-min-height 5)
           (step 0)
           (start-before nil)
           (start-after-down nil)
           (start-after-up nil)
           (sel-after-scroll nil)
           (ml-text nil)
           (cv-binding 'unset)
           (mv-binding 'unset))
      (unwind-protect
          (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                     (lambda (keymap &optional _prompt)
                       (setq step (1+ step))
                       (let* ((mbuf (get-buffer dp-window-utility--menu-buffer-name))
                              (mwin (and mbuf (get-buffer-window mbuf))))
                         (pcase step
                           (1
                            (setq start-before (window-start mwin)
                                  ml-text (with-current-buffer mbuf
                                            (and (listp mode-line-format)
                                                 (mapconcat #'identity
                                                            mode-line-format "")))
                                  cv-binding (lookup-key keymap (kbd "C-v"))
                                  mv-binding (lookup-key keymap (kbd "M-v")))
                            (kbd "C-M-v"))
                           (2
                            (setq start-after-down (window-start mwin)
                                  sel-after-scroll (selected-window))
                            (kbd "C-M-S-v"))
                           (3
                            (setq start-after-up (window-start mwin))
                            [?1]))))))
            (let ((res (dp-window-utility-dispatch-prompt buf nil)))
              (expect (plist-get res :action) :to-be 'window)
              (expect (plist-get res :window) :to-be w1))
            (expect ml-text :to-match "Scroll:")
            (expect start-after-down :to-be-greater-than start-before)
            (expect start-after-up :to-be-less-than start-after-down)
            (expect sel-after-scroll :to-be w1)
            (expect cv-binding :to-be nil)
            (expect mv-binding :to-be nil))
        (kill-buffer buf))))

  (it "falls back to compact echo-area prompt with overlays when frame is below min column width or height"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (buf (get-buffer-create "*small-frame*")))
      (unwind-protect
          (dolist (mode '(narrow short))
            (let ((dp-menu-min-column-width (if (eq mode 'narrow) 200 20))
                  (dp-menu-min-height (if (eq mode 'short) 100 5))
                  (menu-existed nil)
                  (seen-prompt nil)
                  (had-overlay nil))
              (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                         (lambda (_keymap &optional prompt)
                           (setq seen-prompt prompt
                                 menu-existed
                                 (and (get-buffer dp-window-utility--menu-buffer-name)
                                      (get-buffer-window
                                       (get-buffer dp-window-utility--menu-buffer-name))))
                           (with-current-buffer (window-buffer w1)
                             (setq had-overlay
                                   (cl-some (lambda (ov) (eq (overlay-get ov 'window) w1))
                                            (overlays-in (point-min) (point-max)))))
                           [?1])))
                (let ((res (dp-window-utility-dispatch-prompt buf nil)))
                  (expect (plist-get res :action) :to-be 'window)
                  (expect (plist-get res :window) :to-be w1)))
              (expect menu-existed :to-be nil)
              (expect had-overlay :to-be-truthy)
              (expect seen-prompt :to-match "Frame too small for menu")))
        (kill-buffer buf))))

  (it "honors custom user scroll-other-window bindings in the dispatch prompt"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (buf (get-buffer-create "*custom-scroll*"))
           (dp-split-actions
            (cl-loop for ch in '(?a ?b ?c ?d ?e ?f ?g ?h ?i ?j ?k ?l ?m ?n ?o ?p ?q ?r)
                     collect (list ch #'split-window-below
                                   (format "Split action %c" ch))))
           (step 0)
           (start-before nil)
           (start-after nil)
           (old-global (current-global-map))
           (custom-map (copy-keymap old-global)))
      (define-key custom-map (kbd "C-c s") #'scroll-other-window)
      (unwind-protect
          (progn
            (use-global-map custom-map)
            (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                       (lambda (&rest _)
                         (setq step (1+ step))
                         (let* ((mbuf (get-buffer dp-window-utility--menu-buffer-name))
                                (mwin (and mbuf (get-buffer-window mbuf))))
                           (pcase step
                             (1
                              (setq start-before (window-start mwin))
                              (kbd "C-c s"))
                             (2
                              (setq start-after (window-start mwin))
                              [?1]))))))
              (let ((res (dp-window-utility-dispatch-prompt buf nil)))
                (expect (plist-get res :window) :to-be w1))
              (expect start-after :to-be-greater-than start-before)))
        (use-global-map old-global)
        (kill-buffer buf))))

  (it "handles multi-key prefix input and DEL prefix cancel cleanly"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (dp-window-keys '(?a ?s))
           (w1 (selected-window))
           (w2 (split-window w1 nil 'below))
           (w3 (split-window w2 nil 'right))
           (buf (get-buffer-create "*multi-key*"))
           ;; 3 windows with 2 keys -> "aa", "as", "sa".
           ;; Press a -> prefix "a-", press DEL -> cleared, press s -> "s-", press a -> w3!
           (keys (list [?a] [?\177] [?s] [?a]))
           (prompts nil))
      (unwind-protect
          (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                     (lambda (_keymap &optional prompt)
                       (push prompt prompts)
                       (pop keys))))
            (let ((res (dp-window-utility-dispatch-prompt buf nil)))
              (expect (plist-get res :action) :to-be 'window)
              (expect (plist-get res :window) :to-be w3))
            (setq prompts (nreverse prompts))
            (expect (nth 1 prompts) :to-match "Window key: a-")
            (expect (nth 3 prompts) :to-match "Window key: s-"))
        (when (window-live-p w3) (delete-window w3))
        (when (window-live-p w2) (delete-window w2))
        (kill-buffer buf))))

  (it "splits 1 splittable window immediately (even if dedicated), reads target for >1, and rejects 0 splittable"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (side-buf (get-buffer-create "*split-side*"))
           (ded-buf (get-buffer-create "*split-ded*"))
           (target-buf (get-buffer-create "*split-target*"))
           (w-side (display-buffer-in-side-window side-buf '((side . right))))
           w-new)
      ;; Sole normal window w1 is dedicated to ded-buf, plus side window -> 1 splittable!
      (set-window-buffer w1 ded-buf)
      (set-window-dedicated-p w1 t)
      (unwind-protect
          (progn
            ;; Case 1: 1 splittable window -> splits immediately on 'b' with TYPE = 'window
            (let ((read-count 0))
              (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                         (lambda (&rest _)
                           (setq read-count (1+ read-count))
                           [?b])))
                (setq w-new (dp-action-choose-window target-buf '((dedicated . t))))
                (expect read-count :to-be 1)
                (expect (window-live-p w-new) :to-be-truthy)
                (expect (not (eq w-new w1)) :to-be-truthy)
                (expect (window-buffer w-new) :to-be target-buf)
                ;; TYPE = 'window applies (dedicated . t) to the newly split window!
                (expect (window-dedicated-p w-new) :to-be-truthy)
                ;; Original dedicated window remains dedicated to ded-buf
                (expect (window-dedicated-p w1) :to-be-truthy)
                (expect (window-buffer w1) :to-be ded-buf)))
            ;; Case 2: >1 splittable windows (w1 + w-new) -> split-target read
            ;; Press r (split right), try side window label (rejected), press 1 (dedicated w1 -> splittable!)
            (let* ((scope-now (dp-window-utility--scope-windows))
                   (side-idx (1+ (cl-position w-side scope-now)))
                   (keys (list [?r]
                               (vector (+ ?0 side-idx))
                               [?1]))
                   (msgs nil)
                   w-split2)
              (unwind-protect
                  (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                             (lambda (&rest _) (pop keys)))
                            ((symbol-function 'message)
                             (lambda (fmt &rest args)
                               (push (apply #'format fmt args) msgs))))
                    (let ((res (dp-window-utility-dispatch-prompt target-buf nil)))
                      (expect (plist-get res :action) :to-be 'split)
                      (setq w-split2 (plist-get res :window))
                      (expect (window-live-p w-split2) :to-be-truthy)
                      (expect (window-dedicated-p w-split2) :to-be nil)
                      (expect (cl-some (lambda (m) (string-match-p "side window" m)) msgs)
                              :to-be-truthy)))
                (when (window-live-p w-split2) (delete-window w-split2))))
            ;; Case 3: 0 splittable windows (unsplittable frame) -> reports and remains open
            (let ((orig-fp (symbol-function 'frame-parameter))
                  (keys (list [?b] (kbd "M-b")))
                  (msgs nil))
              (cl-letf (((symbol-function 'frame-parameter)
                         (lambda (frame param)
                           (if (eq param 'unsplittable) t
                             (funcall orig-fp frame param))))
                        ((symbol-function 'dp-window-utility--read-key-vector)
                         (lambda (&rest _) (pop keys)))
                        ((symbol-function 'message)
                         (lambda (fmt &rest args)
                           (push (apply #'format fmt args) msgs))))
                (let ((res (dp-window-utility-dispatch-prompt target-buf nil)))
                  (expect (plist-get res :action) :to-be 'bypass)
                  (expect (cl-some (lambda (m) (string-match-p "no splittable" m)) msgs)
                          :to-be-truthy)))))
        (when (window-live-p w-new)
          (set-window-dedicated-p w-new nil)
          (delete-window w-new))
        (when (window-live-p w-side) (delete-window w-side))
        (set-window-dedicated-p w1 nil)
        (kill-buffer side-buf)
        (kill-buffer ded-buf)
        (kill-buffer target-buf))))

  (it "handles C-g abort, M-b Bypass pivot, M-n Leave undisplayed, and M-c Use caller intent"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (w2 (split-window w1 nil 'below))
           (buf (get-buffer-create "*outcomes*")))
      (set-window-dedicated-p w1 t)
      (select-window w1)
      (dp-action-mode +1)
      (unwind-protect
          (progn
            ;; 1. C-g aborts with quit and runs NO later action functions
            (let ((later-ran nil)
                  (quitted nil))
              (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                         (lambda (&rest _) (kbd "C-g")))
                        ((symbol-function 'display-buffer-pop-up-window)
                         (lambda (_b _a) (setq later-ran t) w2)))
                (condition-case nil
                    (display-buffer buf '((display-buffer-pop-up-window)))
                  (quit (setq quitted t)))
                (expect quitted :to-be t)
                (expect later-ran :to-be nil)
                ;; Menu and overlays cleaned up on quit
                (expect (get-buffer dp-window-utility--menu-buffer-name) :to-be nil)))

            ;; 2. M-b Bypass pivot returns nil without quit; later function gets ORIGINAL untouched alist
            (let ((seen-ded 'unset)
                  (keys (list (kbd "M-1") (kbd "M-b")))
                  (other-buf (get-buffer-create "*outcomes-other*")))
              (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                         (lambda (&rest _) (pop keys)))
                        ((symbol-function 'display-buffer-pop-up-window)
                         (lambda (b a)
                           (setq seen-ded (alist-get 'dedicated a))
                           (set-window-buffer w2 b)
                           w2)))
                (let ((win (display-buffer
                            buf '((display-buffer-pop-up-window)
                                  (dedicated . t)))))
                  (expect win :to-be w2)
                  ;; M-1 toggle is local only; bypass hands original (dedicated . t) to Emacs
                  (expect seen-ded :to-be t)))
              ;; Reset w2 so subsequent sub-cases reach the dispatch prompt instead of reusing w2
              (set-window-buffer w2 other-buf)

              ;; 3. M-n Leave undisplayed: only active when allow-no-window is non-nil
              (let ((later-ran nil))
                (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                           (lambda (&rest _) (kbd "M-n")))
                          ((symbol-function 'display-buffer-pop-up-window)
                           (lambda (_b _a) (setq later-ran t) w2)))
                  (let ((res (display-buffer
                              buf '((display-buffer-pop-up-window)
                                    (allow-no-window . t)))))
                    (expect res :to-be nil)
                    (expect later-ran :to-be nil))))
              ;; Without allow-no-window, M-n is NOT bound (ignored, remains open until next key)
              (let ((keys (list (kbd "M-n") [?2])))
                (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                           (lambda (&rest _) (pop keys))))
                  (expect (display-buffer buf) :to-be w2)))
              (set-window-buffer w2 other-buf)

              ;; 4. M-c Use caller intent runs caller's function list with locally toggled alist
              ;; and re-opens prompt if all caller functions return nil
              (let ((seen-ded 'unset)
                    (caller-calls 0)
                    (keys (list (kbd "M-1") (kbd "M-c"))))
                (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                           (lambda (&rest _) (pop keys)))
                          ((symbol-function 'display-buffer-pop-up-window)
                           (lambda (b a)
                             (setq caller-calls (1+ caller-calls)
                                   seen-ded (alist-get 'dedicated a))
                             (set-window-buffer w2 b)
                             w2)))
                  (let ((win (display-buffer
                              buf '((display-buffer-pop-up-window)
                                    (dedicated . t)))))
                    (expect win :to-be w2)
                    (expect caller-calls :to-be 1)
                    ;; M-1 toggled dedicated off -> shadowed as nil for caller intent run!
                    (expect seen-ded :to-be nil))))
              (set-window-buffer w2 other-buf)
              ;; Caller function returning nil re-opens dispatch prompt
              (let ((keys (list (kbd "M-c") [?2]))
                    (caller-calls 0))
                (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                           (lambda (&rest _) (pop keys)))
                          ((symbol-function 'display-buffer-pop-up-window)
                           (lambda (_b _a)
                             (setq caller-calls (1+ caller-calls))
                             nil)))
                  (let ((win (display-buffer
                              buf '((display-buffer-pop-up-window)))))
                    (expect win :to-be w2)
                    (expect caller-calls :to-be 1))))
              (kill-buffer other-buf)))
        (dp-action-mode -1)
        (set-window-dedicated-p w1 nil)
        (when (window-live-p w2) (delete-window w2))
        (kill-buffer buf))))

  (it "re-opens prompt on split failure, supports DEL back from split-target read, and propagates TYPE properly"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (w2 (split-window w1 nil 'below))
           (buf (get-buffer-create "*split-recover*"))
           (other (get-buffer-create "*split-other*")))
      (set-window-buffer w1 other)
      (set-window-buffer w2 other)
      (select-window w1)
      (unwind-protect
          (progn
            ;; DEL during split-target read returns to main prompt; then [1] displays with TYPE 'reuse
            ;; (normal window does NOT become dedicated even with (dedicated . t), and inhibits same-window cleared)
            (let ((keys (list [?b] [?\177] [?1])))
              (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                         (lambda (&rest _) (pop keys))))
                (let ((win (dp-action-choose-window
                            buf '((dedicated . t) (inhibit-same-window . t)))))
                  (expect win :to-be w1)
                  (expect (window-buffer w1) :to-be buf)
                  (expect (window-dedicated-p w1) :to-be nil))))
            ;; Split error reports message, re-opens menu, and allows picking w2
            (set-window-buffer w1 other)
            (let ((dp-split-actions
                   (list (list ?x (lambda () (error "too tiny")) "Failing split")))
                  (keys (list [?x] [?1] [?2]))
                  (msgs nil))
              (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                         (lambda (&rest _) (pop keys)))
                        ((symbol-function 'message)
                         (lambda (fmt &rest args)
                           (push (apply #'format fmt args) msgs))))
                (let ((win (dp-action-choose-window buf nil)))
                  (expect win :to-be w2)
                  (expect (cl-some (lambda (m) (string-match-p "too tiny" m)) msgs)
                          :to-be-truthy)))))
        (when (window-live-p w2) (delete-window w2))
        (kill-buffer buf)
        (kill-buffer other))))

  (it "never clobbers an existing bottom side window when horizontal split is impossible"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (comp (get-buffer-create "*comp-noclopper*"))
           (target (get-buffer-create "*target-noclopper*"))
           (w-comp (display-buffer-in-side-window
                    comp '((side . bottom) (slot . 0) (window-height . 6))))
           (orig-params (copy-alist (window-parameters w-comp)))
           (menu-seen 'unset)
           (prompt-seen nil))
      (unwind-protect
          (progn
            ;; Case 1: window-min-width too large to split w-comp horizontally -> echo-area fallback,
            ;; w-comp buffer/slot/parameters completely untouched!
            (let ((window-min-width 45))
              (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                         (lambda (_keymap &optional prompt)
                           (setq prompt-seen prompt
                                 menu-seen (get-buffer-window
                                            (get-buffer dp-window-utility--menu-buffer-name)))
                           (kbd "M-b"))))
                (let ((res (dp-window-utility-dispatch-prompt
                            target nil :default "Default cue")))
                  (expect (plist-get res :action) :to-be 'bypass)))
              (expect menu-seen :to-be nil)
              (expect prompt-seen :to-match "Frame too small for menu")
              ;; Dispatch prompt default is ALWAYS shown even in small-frame echo-area fallback!
              (expect prompt-seen :to-match "Default: Default cue")
              (expect (window-live-p w-comp) :to-be-truthy)
              (expect (window-buffer w-comp) :to-be comp)
              (expect (window-parameter w-comp 'window-slot) :to-be 0)
              (expect (window-parameter w-comp 'no-other-window)
                      :to-be (alist-get 'no-other-window orig-params)))
            ;; Case 2: short existing bottom side window (height 3 < min-height 5) -> untouched!
            (delete-window w-comp)
            (setq w-comp (display-buffer-in-side-window
                          comp '((side . bottom) (slot . 0)
                                 (window-height . 3)
                                 (preserve-size . (nil . t)))))
            (setq menu-seen 'unset)
            (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                       (lambda (&rest _)
                         (setq menu-seen (get-buffer-window
                                          (get-buffer dp-window-utility--menu-buffer-name)))
                         (kbd "M-b"))))
              (dp-window-utility-dispatch-prompt target nil)
              (expect menu-seen :to-be nil)
              (expect (window-live-p w-comp) :to-be-truthy)
              (expect (window-buffer w-comp) :to-be comp)
              (expect (window-parameter w-comp 'window-slot) :to-be 0)))
        (when (window-live-p w-comp) (delete-window w-comp))
        (kill-buffer comp)
        (kill-buffer target))))

  (it "updates Windows group faces and preserves echo-area rejection feedback during split-target read"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (w2 (split-window w1 nil 'below))
           (ded-buf (get-buffer-create "*split-ui-ded*"))
           (side-buf (get-buffer-create "*split-ui-side*"))
           (target (get-buffer-create "*split-ui-target*"))
           (w-side (display-buffer-in-side-window side-buf '((side . right))))
           (step 0)
           (w1-face-main nil)
           (w1-face-split nil)
           (w-side-face-split nil)
           (prompt-after-reject nil)
           (scope-now nil)
           (side-idx nil)
           w-new)
      (set-window-buffer w1 ded-buf)
      (set-window-dedicated-p w1 t)
      (setq scope-now (dp-window-utility--scope-windows))
      (setq side-idx (1+ (cl-position w-side scope-now)))
      (unwind-protect
          (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                     (lambda (_keymap &optional prompt)
                       (setq step (1+ step))
                       (let* ((mbuf (get-buffer dp-window-utility--menu-buffer-name))
                              (find-label-face
                               (lambda (lbl)
                                 (when mbuf
                                   (with-current-buffer mbuf
                                     (save-excursion
                                       (goto-char (point-min))
                                       (when (search-forward (format "[%s]" lbl) nil t)
                                         (get-text-property (match-beginning 0) 'face))))))))
                         (pcase step
                           (1
                            (setq w1-face-main (funcall find-label-face "1"))
                            [?r])
                           (2
                            (setq w1-face-split (funcall find-label-face "1")
                                  w-side-face-split (funcall find-label-face
                                                             (number-to-string side-idx)))
                            ;; Reject side window first
                            (vector (+ ?0 side-idx)))
                           (3
                            ;; Echo-area feedback must be present in the NEXT prompt!
                            (setq prompt-after-reject prompt)
                            [?1]))))))
            (let ((res (dp-window-utility-dispatch-prompt target nil)))
              (expect (plist-get res :action) :to-be 'split)
              (setq w-new (plist-get res :window)))
            ;; In main mode, dedicated w1 was ineligible; in split-target mode, it is splittable!
            (expect w1-face-main :to-be 'dp-ineligible-label)
            (expect w1-face-split :to-be 'dp-eligible-label)
            ;; Side window remains ineligible in split-target mode
            (expect w-side-face-split :to-be 'dp-ineligible-label)
            ;; Rejection reason was NOT wiped out by the next read prompt
            (expect prompt-after-reject :to-match "cannot split \\*split-ui-side\\* (side window)"))
        (when (window-live-p w-new) (delete-window w-new))
        (when (window-live-p w-side) (delete-window w-side))
        (set-window-dedicated-p w1 nil)
        (when (window-live-p w2) (delete-window w2))
        (kill-buffer ded-buf)
        (kill-buffer side-buf)
        (kill-buffer target))))

  (it "preserves scrolled menu window-start AND window-point across toggle refreshes"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (buf (get-buffer-create "*scroll-refresh*"))
           (dp-split-actions
            (cl-loop for ch in '(?a ?b ?c ?d ?e ?f ?g ?h ?i ?j ?k ?l ?m ?n ?o ?p ?q ?r)
                     collect (list ch #'split-window-below
                                   (format "Split action %c" ch))))
           (step 0)
           (start-scrolled nil)
           (start-after-toggle nil)
           (point-after-toggle nil))
      (unwind-protect
          (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                     (lambda (&rest _)
                       (setq step (1+ step))
                       (let* ((mbuf (get-buffer dp-window-utility--menu-buffer-name))
                              (mwin (and mbuf (get-buffer-window mbuf))))
                         (pcase step
                           (1 (kbd "C-M-v"))
                           (2
                            (setq start-scrolled (window-start mwin))
                            (kbd "M-1"))
                           (3
                            (setq start-after-toggle (window-start mwin)
                                  point-after-toggle (window-point mwin))
                            [?1]))))))
            (let ((res (dp-window-utility-dispatch-prompt buf '((dedicated . t)))))
              (expect (plist-get res :window) :to-be w1))
            (expect start-scrolled :to-be-greater-than 1)
            (expect start-after-toggle :to-be-greater-than 1)
            (expect point-after-toggle :not :to-be-less-than start-after-toggle))
        (kill-buffer buf))))

  (it "handles real read-key-sequence-vector input including TTY ESC, ESC C-g, C-c C-g, and scroll keys"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (w2 (split-window w1 nil 'below))
           (buf (get-buffer-create "*real-keys*")))
      (unwind-protect
          (progn
            ;; Real TTY ESC 1 (toggle dedicated off) + ?2
            (let ((unread-command-events (list 27 ?1 ?2)))
              (let ((res (dp-window-utility-dispatch-prompt buf '((dedicated . t)))))
                (expect (plist-get res :action) :to-be 'window)
                (expect (plist-get res :window) :to-be w2)
                (expect (assq 'dedicated (plist-get res :alist))
                        :to-equal '(dedicated . nil))))
            ;; Real ESC C-g (C-M-g) aborts cleanly!
            (let ((unread-command-events (list 27 7))
                  (quitted nil))
              (condition-case nil
                  (dp-window-utility-dispatch-prompt buf nil)
                (quit (setq quitted t)))
              (expect quitted :to-be t)
              (expect (get-buffer dp-window-utility--menu-buffer-name) :to-be nil))
            ;; Real C-c C-g mid custom multi-key scroll prefix aborts cleanly!
            (let* ((old-global (current-global-map))
                   (cmap (copy-keymap old-global))
                   (quitted nil))
              (define-key cmap (kbd "C-c s") #'scroll-other-window)
              (unwind-protect
                  (progn
                    (use-global-map cmap)
                    (let ((unread-command-events (list 3 7)))
                      (condition-case nil
                          (dp-window-utility-dispatch-prompt buf nil)
                        (quit (setq quitted t))))
                    (expect quitted :to-be t))
                (use-global-map old-global)))
            ;; Real M-next / M-prior scroll + TTY ESC b bypass
            (let ((unread-command-events (list 'M-next 'M-prior 27 ?b)))
              (let ((res (dp-window-utility-dispatch-prompt buf nil)))
                (expect (plist-get res :action) :to-be 'bypass))))
        (when (window-live-p w2) (delete-window w2))
        (kill-buffer buf))))

  (it "hardens wrapping, key sanitization, two-pass allocation, and dead-window recovery"
    ;; Wrapping leading-space line with long unbreakable word produces NO empty line
    (let ((wrapped (dp-window-utility--wrap-line
                    "  [b] Supercalifragilisticexpialidocious" 12 6)))
      (expect (cl-some #'string-empty-p wrapped) :to-be nil)
      (dolist (line wrapped)
        (expect (<= (string-width line) 12) :to-be-truthy)))
    ;; Newlines and tabs are sanitized and never break column alignment
    (let* ((groups '(("Windows" "[1] bad\nname\there")
                     ("Dispatch actions" "Other" "  [M-b] Bypass pivot")))
           (rows (dp-window-utility--layout-groups groups 60 20)))
      (dolist (row rows)
        (expect (string-match-p "[\n\t]" row) :to-be nil)
        (expect (<= (string-width row) 60) :to-be-truthy)))
    ;; C-g and DEL are excluded from window keys; all-digit split keys fall back to letters
    (expect (dp-window-utility--usable-window-keys '(?\C-g ?\177 ?a ?s) nil)
            :to-equal '(?a ?s))
    (let* ((digit-splits (mapcar (lambda (d) (list d #'split-window-below "S"))
                                 '(?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9)))
           (labels (cl-letf (((symbol-function 'message) #'ignore))
                     (dp-window-utility--generate-window-labels
                      3 '(?1 ?2 ?3) digit-splits))))
      (expect labels :to-equal '("a" "b" "c")))
    ;; Two-pass allocation: colliding toggle cannot steal another present toggle's preferred key
    (let* ((used (list (dp-window-utility--meta-event ?1)
                       (dp-window-utility--meta-event ?7)
                       (dp-window-utility--meta-event ?8)
                       (dp-window-utility--meta-event ?9)
                       (dp-window-utility--meta-event ?2)
                       (dp-window-utility--meta-event ?3)))
           (alloc (car (dp-window-utility--allocate-keys-batch
                        'digit '(?1 ?4) used))))
      ;; ?4 keeps its preferred M-4; ?1 takes next free M-5 instead of stealing M-4!
      (expect (nth 1 alloc) :to-be (dp-window-utility--meta-event ?4))
      (expect (nth 0 alloc) :not :to-be (dp-window-utility--meta-event ?4)))
    ;; Dead window returned from dispatch prompt re-opens prompt with feedback
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (w2 (split-window w1 nil 'below))
           (w-dead (split-window w2 nil 'right))
           (buf (get-buffer-create "*dead-recover*"))
           (calls 0)
           (seen-fb nil))
      (delete-window w-dead)
      (unwind-protect
          (cl-letf (((symbol-function 'dp-window-utility-dispatch-prompt)
                     (lambda (_b a &rest args)
                       (setq calls (1+ calls))
                       (if (= calls 1)
                           (list :action 'window :window w-dead :alist a)
                         (setq seen-fb (plist-get args :initial-feedback))
                         (list :action 'window :window w2 :alist a)))))
            (let ((win (dp-action-choose-window buf nil)))
              (expect win :to-be w2)
              (expect calls :to-be 2)
              (expect seen-fb :to-match "no longer live")))
        (when (window-live-p w2) (delete-window w2))
        (kill-buffer buf))))

  (it "excludes ESC, supports Meta split keys with end-to-end collision reallocation, and ignores active input methods"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (w2 (split-window w1 nil 'below))
           (buf (get-buffer-create "*meta-split-im*")))
      (unwind-protect
          (progn
            ;; ESC (?\e) in window-keys or split-actions is excluded and never crashes Meta bindings
            (expect (dp-window-utility--usable-window-keys '(?\e ?\C-g ?\177 ?a ?s) nil)
                    :to-equal '(?a ?s))
            (let ((dp-split-actions '((?\e split-window-below "Split ESC")))
                  (dp-window-keys '(?\e ?1 ?2 ?3)))
              (let ((unread-command-events (list 27 ?b)))
                (let ((res (dp-window-utility-dispatch-prompt buf nil)))
                  (expect (plist-get res :action) :to-be 'bypass))))
            ;; Meta split keys (?\M-b and ?\M-1) win; Bypass reallocates to M-a and dedicated to M-7!
            (let* ((dp-split-actions
                    (list (list ?\M-b #'split-window-below "Split M-b")
                          (list ?\M-1 #'split-window-right "Split M-1")))
                   (seen-bypass nil))
              ;; Press M-7 (reallocated dedicated toggle off), then ?2 -> (dedicated . nil)
              (let ((unread-command-events (list ?\M-7 ?2)))
                (let ((res (dp-window-utility-dispatch-prompt buf '((dedicated . t)))))
                  (expect (plist-get res :action) :to-be 'window)
                  (expect (plist-get res :window) :to-be w2)
                  (expect (assq 'dedicated (plist-get res :alist))
                          :to-equal '(dedicated . nil))))
              ;; Press M-a -> reallocated Bypass pivot!
              (let ((unread-command-events (list ?\M-a)))
                (setq seen-bypass (dp-window-utility-dispatch-prompt buf nil))
                (expect (plist-get seen-bypass :action) :to-be 'bypass))
              ;; Press M-b -> actually executes the ?\M-b split action!
              (let ((unread-command-events (list ?\M-b ?1))
                    w-split)
                (unwind-protect
                    (let ((res (dp-window-utility-dispatch-prompt buf nil)))
                      (expect (plist-get res :action) :to-be 'split)
                      (setq w-split (plist-get res :window))
                      (expect (window-live-p w-split) :to-be-truthy))
                  (when (window-live-p w-split) (delete-window w-split)))))
            ;; Active input-method-function must NOT intercept dispatch prompt keys
            (let ((input-method-function (lambda (_key) (list ?あ)))
                  (unread-command-events (list ?2)))
              (let ((res (dp-window-utility-dispatch-prompt buf nil)))
                (expect (plist-get res :action) :to-be 'window)
                (expect (plist-get res :window) :to-be w2)))
            ;; GUI C-M-g (?\M-\C-g) aborts cleanly in main prompt and split-target read
            (let ((unread-command-events (list ?\M-\C-g))
                  (quitted nil))
              (condition-case nil
                  (dp-window-utility-dispatch-prompt buf nil)
                (quit (setq quitted t)))
              (expect quitted :to-be t))
            (let ((unread-command-events (list ?b ?\M-\C-g))
                  (quitted nil))
              (condition-case nil
                  (dp-window-utility-dispatch-prompt buf nil)
                (quit (setq quitted t)))
              (expect quitted :to-be t))
            ;; C-M-g is never allocated even when all other Meta/C-M- letters are taken
            (let* ((all-meta (mapcar #'dp-window-utility--meta-event
                                     (number-sequence ?a ?z)))
                   (all-cm-except-g
                    (mapcar #'dp-window-utility--ctrl-meta-event
                            (cl-remove ?g (number-sequence ?a ?z))))
                   (ev (dp-window-utility--allocate-key
                        'letter ?c (append all-meta all-cm-except-g))))
              (expect ev :to-be nil)))
        (when (window-live-p w2) (delete-window w2))
        (kill-buffer buf))))

  (it "keeps window-start line-aligned on toggle refresh, resets/restores scroll around split-target read, and isolates menu buffer settings"
    (delete-other-windows)
    (let* ((noninteractive nil)
           (w1 (selected-window))
           (w2 (split-window w1 nil 'below))
           (buf (get-buffer-create "*scroll-bolp*"))
           (dp-split-actions
            (cl-loop for ch in '(?a ?b ?c ?d ?e ?f ?g ?h ?i ?j ?k ?l ?m ?n ?o ?p ?q ?r)
                     collect (list ch #'split-window-below
                                   (format "Split action %c" ch))))
           (step 0)
           (line-before nil)
           (bolp-after-toggle nil)
           (line-after-toggle nil)
           (start-in-split nil)
           (line-after-del nil)
           (seen-line-nums 'unset)
           (seen-trail-ws 'unset)
           (seen-fill-col 'unset)
           (orig-dln (default-value 'display-line-numbers))
           (orig-stw (default-value 'show-trailing-whitespace))
           (orig-dfc (default-value 'display-fill-column-indicator)))
      (unwind-protect
          (progn
            (setq-default display-line-numbers t
                          show-trailing-whitespace t
                          display-fill-column-indicator t)
            (cl-letf (((symbol-function 'dp-window-utility--read-key-vector)
                       (lambda (&rest _)
                         (setq step (1+ step))
                         (let* ((mbuf (get-buffer dp-window-utility--menu-buffer-name))
                                (mwin (and mbuf (get-buffer-window mbuf))))
                           (pcase step
                             (1
                              (setq seen-line-nums (buffer-local-value 'display-line-numbers mbuf)
                                    seen-trail-ws (buffer-local-value 'show-trailing-whitespace mbuf)
                                    seen-fill-col (buffer-local-value 'display-fill-column-indicator mbuf))
                              (kbd "C-M-v"))
                             (2
                              (setq line-before
                                    (with-current-buffer mbuf
                                      (line-number-at-pos (window-start mwin))))
                              (kbd "M-1"))
                             (3
                              (with-current-buffer mbuf
                                (goto-char (window-start mwin))
                                (setq bolp-after-toggle (bolp)
                                      line-after-toggle (line-number-at-pos (point))))
                              [?b])
                             (4
                              (setq start-in-split (window-start mwin))
                              [?\177])
                             (5
                              (setq line-after-del
                                    (with-current-buffer mbuf
                                      (line-number-at-pos (window-start mwin))))
                              [?1]))))))
              (let ((res (dp-window-utility-dispatch-prompt
                          buf '((dedicated . t) (window-height . 20)))))
                (expect (plist-get res :window) :to-be w1))
              (expect seen-line-nums :to-be nil)
              (expect seen-trail-ws :to-be nil)
              (expect seen-fill-col :to-be nil)
              (expect line-before :to-be-greater-than 1)
              (expect bolp-after-toggle :to-be t)
              (expect line-after-toggle :to-be line-before)
              (expect start-in-split :to-be 1)
              (expect line-after-del :to-be line-before)))
        (setq-default display-line-numbers orig-dln
                      show-trailing-whitespace orig-stw
                      display-fill-column-indicator orig-dfc)
        (when (window-live-p w2) (delete-window w2))
        (kill-buffer buf))))

  (it "restores bottom side window snapshots if split-window-no-error fails, handles hscroll/invisible overlays, word-boundary wrap, GUI scroll areas, and small-frame toggle keys"
    ;; 1. Word-boundary wrap does not prematurely break when tail begins with space
    (expect (dp-window-utility--wrap-line "Caller: direction right" 17 8)
            :to-equal '("Caller: direction" "        right"))

    ;; 2. --resolve-default-desc supports custom :action symbols
    (expect (dp-window-utility--resolve-default-desc
             '(:action full-frame) nil
             '(:key-label "M-c" :label "Display full frame" :action full-frame))
            :to-match "\\[M-c\\] Display full frame")

    ;; 3. --bind-scroll-keys binds mouse-wheel areas and skips menu-bar and clobbering sequences
    (let ((map (make-sparse-keymap)))
      (define-key map (kbd "M-1") '(toggle . dedicated))
      (dp-window-utility--bind-scroll-keys
       map (cons (list [menu-bar edit scroll] [27 ?1 ?x] (kbd "C-c s")) nil) nil)
      (expect (lookup-key map [menu-bar]) :to-be nil)
      (expect (lookup-key map (kbd "M-1")) :to-equal '(toggle . dedicated))
      (expect (lookup-key map (kbd "C-c s")) :to-equal '(scroll . up))
      (expect (lookup-key map [mode-line mouse-5])
              :to-equal '(mouse-scroll . wheel-down))
      (expect (lookup-key map [left-fringe wheel-down])
              :to-equal '(mouse-scroll . wheel-down))
      (expect (lookup-key map [vertical-scroll-bar wheel-up])
              :to-equal '(mouse-scroll . wheel-up)))

    ;; 4. --no-splittable-reason reports "only side windows" when dead and live side windows mix
    (delete-other-windows)
    (let* ((w1 (selected-window))
           (w-dead (split-window w1 nil 'below))
           (sbuf (get-buffer-create "*side-mix*"))
           (w-side (display-buffer-in-side-window sbuf '((side . right)))))
      (delete-window w-dead)
      (unwind-protect
          (expect (dp-window-utility--no-splittable-reason
                   (selected-frame)
                   (list (list :window w-dead) (list :window w-side)))
                  :to-equal "only side windows")
        (when (window-live-p w-side) (delete-window w-side))
        (kill-buffer sbuf)))

    ;; 5. --overlay-position advances past leading invisible overlays and offsets hscroll
    (delete-other-windows)
    (let* ((w1 (selected-window))
           (w2 (split-window w1 nil 'below))
           (b-invis (get-buffer-create "*ov-invis*"))
           (b-hsc (get-buffer-create "*ov-hscroll*")))
      (unwind-protect
          (progn
            (with-current-buffer b-invis
              (insert "HIDDEN_PREFIXvisible text\n")
              (let ((inv (make-overlay 1 14)))
                (overlay-put inv 'invisible t)))
            (set-window-buffer w1 b-invis)
            (expect (dp-window-utility--overlay-position w1) :to-equal '(14 . 0))

            (with-current-buffer b-hsc
              (setq-local truncate-lines t)
              (insert "\n" (make-string 80 ?x) "\n"))
            (set-window-buffer w2 b-hsc)
            (set-window-hscroll w2 15)
            ;; Empty first line on TTY (vis-col = 16) pads with 16 spaces
            (expect (dp-window-utility--overlay-position w2) :to-equal '(1 . 16)))
        (when (window-live-p w2) (delete-window w2))
        (kill-buffer b-invis)
        (kill-buffer b-hsc)))

    ;; 6. Belt-and-suspenders --restore-side-snapshots path + small-frame echo lists individual toggles
    (delete-other-windows)
    (let* ((noninteractive nil)
           (c0 (get-buffer-create "*snap-c0*"))
           (target (get-buffer-create "*snap-target*"))
           (w0 (display-buffer-in-side-window
                c0 '((side . bottom) (slot . 0) (window-height . 8))))
           (seen-prompt nil)
           (seen-menu 'unset))
      (with-current-buffer c0 (insert "line1\nline2\nline3\n"))
      (set-window-point w0 7)
      (let ((prev-before (copy-tree (window-prev-buffers w0))))
        (unwind-protect
            (cl-letf (((symbol-function 'split-window-no-error)
                       (lambda (&rest _) nil))
                      ((symbol-function 'dp-window-utility--read-key-vector)
                       (lambda (_km &optional prompt)
                         (setq seen-prompt prompt
                               seen-menu (get-buffer-window
                                          (get-buffer dp-window-utility--menu-buffer-name)))
                         (kbd "M-b"))))
              (let ((res (dp-window-utility-dispatch-prompt
                          target '((dedicated . t) (window-height . 10)))))
                (expect (plist-get res :action) :to-be 'bypass))
              (expect seen-menu :to-be nil)
              (expect seen-prompt :to-match "\\[M-0\\] settings(on)")
              (expect seen-prompt :to-match "\\[M-1\\] dedicated(on)")
              (expect seen-prompt :to-match "\\[M-4\\] window-height(on)")
              (expect (window-live-p w0) :to-be-truthy)
              (expect (window-buffer w0) :to-be c0)
              (expect (window-point w0) :to-be 7)
              (expect (window-parameter w0 'window-slot) :to-be 0)
              (expect (window-dedicated-p w0) :to-be 'side)
              (expect (window-prev-buffers w0) :to-equal prev-before))
          (when (window-live-p w0) (delete-window w0))
          (kill-buffer c0)
          (kill-buffer target))))))

(provide 'dispatch-prompt-test)

;; Local Variables:
;; read-symbol-shorthands: (("dp-" . "disbuf-pivot-"))
;; End:

;;; dispatch-prompt-test.el ends here
