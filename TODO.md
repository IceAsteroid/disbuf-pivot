# TODO

Current branch: `design/action-rules`.
Normative specification: `docs/DESIGN_RULESET.md`.

## Implementation milestones

Design settled in `docs/DESIGN_RULESET.md`; v0.1.0 Elisp source not yet
updated.  Order of work (see `docs/DESIGN_RULESET.md` section 11):

1. Core options/faces, per-buffer `displayable` / `eligible` /
   `splittable` predicates, cannot-prompt context guards, safe
   `dp-action--action` reentrancy, and `disbuf-pivot-exclude-conditions`.
2. Own window-labeling overlays, built-in split primitives,
   `disbuf-pivot-window-keys` and `disbuf-pivot-split-actions` (`'auto`
   inheriting `aw-keys` / `aw-dispatch-alist` when bound), direct
   `display-buffer-in-side-window` dispatch prompt menu (header, 3
   horizontal groups, split-target read for >1 splittable windows,
   `M-1`..`M-6` + always-present `M-0` with `(KEY . nil)` shadowing),
   `C-g` abort, and cancel nil choice.  Remove `aw-select`,
   `disbuf-pivot-mode-line-help`, and automatic splitting from core.
3. Effective-intent classifier (reuse-first chains like `C-x 5 b`,
   non-list `ACTION` / dynamic `pop-up-frames` /
   `display-buffer-reuse-frames`), `window--display-buffer` `TYPE`
   propagation (`'reuse` / `'window` / `'tab` / `'frame`),
   `inhibit-same-window` override and conflict,
   `display-buffer-full-frame`, `reuse-indirect`, `mode` default, variable-symbol `previous-window`,
   cross-frame reuse default, and `"Use caller intent"` under recursion
   guard.
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

### Minor UI details to finalize during step 2

- Exact default Meta-letter bindings for package dispatch actions (`M-c`
  Use caller intent, `M-q` Cancel, `M-n` Leave undisplayed) and behavior
  if every key of a kind is taken.
- Default built-in key list when `disbuf-pivot-window-keys` is `'auto`
  and `aw-keys` is unbound (e.g. home-row `a s d f g h j k l`), plus
  Windows group width / grid wrapping on narrow frames.

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
