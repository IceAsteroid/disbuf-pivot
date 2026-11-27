# TODO

Current branch: `design/action-rules`.
Normative specification: `docs/DESIGN_RULESET.md`.

## Implementation milestones

Design settled in `docs/DESIGN_RULESET.md`; Milestone 1 implemented,
milestones 2–6 remaining.  Order of work (see `docs/DESIGN_RULESET.md`
section 11):

1. [x] Core options/faces, per-buffer `displayable` / `eligible` /
   `splittable` predicates, cannot-prompt context guards, safe
   `dp-action--action` reentrancy, and `disbuf-pivot-exclude-conditions`.
2. Own window-labeling overlays, own split primitives,
   `disbuf-pivot-window-keys` (default digits `1`–`9`, uniform
   fixed-width multi-key overflow) and `disbuf-pivot-split-actions`
   (default `b`/`r`/`f`, zero `ace-window` coupling), direct
   `display-buffer-in-side-window` dispatch prompt menu (header,
   responsive logical-wrapped 3/2/1 groups governed by
   `disbuf-pivot-menu-min-column-width` and
   `disbuf-pivot-menu-min-height`, other-window scrolling without focus
   change, small-frame echo-area fallback keeping window labels,
   split-target read for >1 splittable windows, `M-1`..`M-6` +
   always-present `M-0` with `(KEY . nil)` shadowing), `C-g` abort, and
   `"Bypass pivot"` (`M-b`) nil choice.  Remove `aw-select`,
   `disbuf-pivot-mode-line-help`, and automatic splitting from core
   (keeping a compatibility bridge for `disbuf-pivot-prefix.el` until
   step 5 removes the legacy split helper and prefix select option).
3. Effective-intent classifier (reuse-first chains like `C-x 5 b`,
   non-list `ACTION` / dynamic `pop-up-frames` /
   `display-buffer-reuse-frames`), `dp-action--run` regulated dispatch
   for `display-buffer-reuse-window` and `display-buffer-same-window`,
   `window--display-buffer` `TYPE` propagation (`'reuse` / `'window` /
   `'tab` / `'frame`), `inhibit-same-window` override and conflict,
   `display-buffer-full-frame`, `reuse-indirect`, `mode` default,
   variable-symbol `previous-window`, cross-frame reuse default, `"Use
   caller intent"` under recursion guard, header info formatting
   (`Caller (<category>): ...`, source-labeled entries, window facts),
   and Section 10 failure-after-choice handling.
4. Tab prompt scope (`disbuf-pivot-tab-prompt-scope`, suffixes,
   reusable tab candidates, single-evaluation `tab-name` / `tab-group`,
   `tab-bar-show` enabling, frame annotation column, scope-relative
   `(closed)` history candidates, no out-of-frame consult preview) and
   existing-vs-new tab/frame preselect rules.
5. Package prefix commands: dedicated one-shot
   `display-buffer-overriding-action` wrapper (avoiding
   `display-buffer-override-next-command`'s double
   `window--display-buffer` call) wired to the dispatch/tab/frame
   prompts; merge `disbuf-pivot-other-window-prefix-select` into
   `disbuf-pivot-action-select`.
6. Buttercup test coverage for `docs/DESIGN_RULESET.md` sections 2–10;
   drop `ace-window` from `Package-Requires`, `Makefile`, and CI; update
   `README.md`, `CONTRIBUTING.md`, and `CHANGELOG.md`.

## Deferred open decisions

### Atom windows (`display-buffer-in-atom-window`)

Deferred; currently `Respect` in `docs/DESIGN_RULESET.md`.

- Without a non-nil `window` entry in the combined action alist,
  `display-buffer-in-atom-window` defaults to the selected window
  (`window.el.gz:692`), which can be unexpected.
- Future option: respect an explicit non-nil `window` entry and regulate
  implicit selected-window attachment with an anchor prompt.

### Prefix commands in child frames

Deferred; current `frame-parent` redirection remains in
`disbuf-pivot-prefix.el`.

- Built-in prefix commands (`same-window-prefix`,
  `other-window-prefix`, `other-tab-prefix`, `other-frame-prefix`)
  operate on the selected frame without redirecting via `frame-parent`.
- Future option: remove the `frame-parent` fallback in
  `dp-prefix--find-last-active-window` and
  `dp-prefix--with-displayable-window`, or keep it if child frames
  remain strictly pop-up frames.
