# Changelog

## Unreleased

### User-visible Changes

- Fix: with `disbuf-pivot-mode-line-help` nil, the dispatch hint
  remains in the echo area; the option controls only the mode-line
  copy.
- Add: `disbuf-pivot-mode-line-help`; nil by default hides the
  dispatch hint in the mode line, non-nil shows it.  It does not affect
  the echo-area dispatch hint or `ace-window-display-mode` labels.
- Doc: describe the consult reader's child-frame cleanup and
  minibuffer-height preservation separately; state the existing-frame
  condition in the frame prefix; qualify the `aw-select` prompt feedback;
  define the window prompt without limiting it to a tab or frame; tighten
  the `display-buffer-alist` entry and naming descriptions; correct the
  0.1.0 release note; and state the pop-up window pairing and enabling
  order in the scope.

### Internal Changes

- Docs: complete the test matrix for the new options, constraints, and
  excluded buffer.
- Docs: name the `disbuf-pivot-action-functions` default and option.
- Docs: replace stale prompt wording; name the window prompt and the
  other-frame prefix order.
- Docs: make new-target tab and frame actions start a new target and
  never select an existing one.
- Docs: reserve nil returns for the cannot-prompt and Respect cases; an
  interactive display failure prompts again or aborts instead of
  running caller fallbacks.
- Docs: classify `display-buffer-use-some-window` and
  `display-buffer-use-least-recent-window` as strategy intents and
  regulate them.
- Docs: note that a child frame's parent may be a top-level or child
  frame, and treat `bump-use-time` as a shared display entry.
- Docs: define the grouped dispatch action list and
  `disbuf-pivot-exclude-conditions`.
- Docs: define the dispatch hint and the dispatch action list; state
  that `disbuf-pivot-mode-line-help` controls only the mode-line
  dispatch hint, not the echo-area one.
- Docs: state that the mode-line help string is a hint, not the
  dispatch actions, and that caller intent info is shown before the
  window prompt.
- Docs: port the remaining action-alist corrections.
- Docs: define "cannot prompt" as a restriction and "no prompt" as the
  behavior.
- Docs: define the contexts where the package cannot prompt, and use
  the term in the ACTION fallback rule.
- Docs: state the fallback behavior of ACTION chains: later functions
  are unregulated fallbacks; caller intent info names the chain; when
  the package cannot prompt or the first function fails, the caller's
  functions run; C-g aborts; "use caller intent" is a user choice.
- Docs: state the first-function rule for a caller's ACTION with several
  functions.
- Docs: define the tab or frame action and child-frame action terms,
  record the top-level and child frame definitions, and regulate the tab
  or frame actions; preselect an existing tab or frame and start a new
  one without a preselect.
- Docs: regulate `display-buffer-below-selected` and
  `display-buffer-at-bottom` in the design and matrix.
- Docs: regulate `display-buffer-in-previous-window` in the design and
  matrix: show the `previous-window` candidate; otherwise use the
  windows that previously showed the buffer.
- Docs: state the `eldev` PATH requirement in `CONTRIBUTING.md`.
- Test: rename the test suite names to the `disbuf-pivot` prefix.
- Docs: import `CONTRIBUTING.md` into `CLAUDE.md`, scope the term file
  to artifacts, add the dependency tree and test file names to
  `CONTRIBUTING.md`, route `docs/DISPLAY_BUFFER_MATRIX.md` from the
  agent and design docs, state the `Co-Authored-By:` trailer rule in
  `docs/GIT_CONVENTION.md`, and remove the duplicated changelog rule.
- Docs: define the caller intent, caller constraint, eligible window,
  dispatch action, split action, and displayable window terms; use the
  package's `display-buffer-alist` entry and the displayable window in
  the README, Commentary, changelog, and test names; rename
  `dp-prefix--with-editing-window` to
  `dp-prefix--with-displayable-window`.
- Docs: add `docs/DESIGN_RULESET.md` as the design authority, define the
  chosen window, caller intent info, cannot display, built-in prefix
  command, and package prefix command terms in
  `docs/DOCUMENTATION_CONVENTION.md`, and record the settled display
  rules.
- Docs: move the maintainer docs under `docs/` and split the git and
  changelog conventions from the terms file.
- Docs: add `CONTRIBUTING.md` for the developer commands, verification,
  and dependency rules, and reduce `AGENTS.md` to the agent index.
- Docs: add `docs/DISPLAY_BUFFER_MATRIX.md`, the Emacs 31.1
  action-function and action-alist matrix used to check the design.
- Docs: define the window prompt and the dispatch prompt in
  `docs/DOCUMENTATION_CONVENTION.md` and use them in the design, README,
  matrix, CONTRIBUTING, and Commentary.

## 0.1.0 - 2026-10-30

### User-visible Changes

- Add: `disbuf-pivot-action-mode`, which installs the package's entry
  in `display-buffer-alist`.  It reuses a window that displays the
  buffer, uses the selected window, splits, or asks with `ace-window`; a
  request for a tab or frame asks for the target, then for a window when
  one is needed.
- Add: `disbuf-pivot-same-window-prefix`,
  `disbuf-pivot-other-window-prefix`,
  `disbuf-pivot-other-tab-prefix`, and
  `disbuf-pivot-other-frame-prefix`.
  `disbuf-pivot-prefix-mode` remaps the four built-in prefix commands to
  these commands; it does not advise `display-buffer`.
- Add: the prefix commands choose the most recently used displayable window
  when the selected window cannot display a buffer.  The window prompt
  says in the echo area when a chosen window cannot display the buffer,
  and shows `? for actions` when `aw-dispatch-alist` binds `?`.
- Add: the frame prompt offers top-level frames, disambiguates repeated
  names, makes a new frame for a new name, and asks for a tab when
  `tab-bar-mode` is active or the frame has more than one tab.
- Add: `disbuf-pivot-tab-bar-read-tab-name` reads tab names from the
  tab bar, the closed-tab history, the configured sort, and the
  annotations.  In `disbuf-pivot-tab-bar.el`,
  `disbuf-pivot-tab-bar-read-function` can replace the plain reader.
- Add: `disbuf-pivot-tab-bar-consult.el`, the optional consult reader
  and the mode that installs it, with the PGTK child-frame cleanup and
  the minibuffer-height preservation.  It needs only `consult` and the
  display package.
- Fix: a nil `pop-up-frames` value no longer asks for a frame; child
  frames are not offered; repeated frame names are disambiguated; the
  tab and frame window prompts honor `inhibit-same-window`; the
  other-window prefix follows `reusable-frames` and
  `inhibit-same-window`; a tab name that occurs more than once selects
  its own tab; the pivot searches the parent frame of a child frame.
- Doc: the package and repository are `disbuf-pivot`; the source URL
  headers name the repository, and the README and codification describe
  the behavior and terms.
