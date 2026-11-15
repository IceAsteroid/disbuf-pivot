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

- Docs: list "driver" in Terms not used; say that the package reads
  the keys, or name the function that reads them.
- Docs: state which windows the dispatch prompt labels: every window in
  the selected tab or frame, drawn on the windows and shown in a
  separate group in the menu with the same keys and faces.  State that
  it reads the keys for the window labels, the dispatch actions, and the
  window-setting toggles, and that the package does not call `aw-select`;
  state that when a Behavior cell lists split actions and cancel, the
  prompt also labels the windows.  The transient rewrite left the set of
  labeled windows undefined.
- Docs: rename the tab reader term to tab prompt and add the frame
  prompt; make the two prompts a standalone entry, separate from the
  tab or frame action and child-frame action terms; replace the stale
  "frame readers" wording with "frame prompt"; the tab reader remains
  the implementation function and replaceable reader, not the prompt
  term.  The current source and README still use the tab reader
  wording.
- Docs: replace the two-prompt rule with the transient dispatch prompt;
  define the intended choice, the window-setting toggle, and the
  ineligible window; add the eligible and ineligible label faces; drop
  the window prompt, the dispatch hint, and the window-settings opt-out
  from the design terms; merge related core terms into single entries;
  name `disbuf-pivot-window-utility-split-p` and its options instead of
  using a split rule term; treat the `can display`, `cannot display`,
  and `do not prompt` forms as prose.  The current source and README
  remain on the two-prompt behavior and the split rule until the design
  is implemented.
- Docs: make the caller's first function the only intent class; state
  that a constraint or window-setting entry is an entry, not a class;
  add the no-display class and the nil choice term; name the later
  functions in Emacs's combined function list instead of "remaining
  display rules"; state that the entry condition receives the caller's
  ACTION and the action function receives the combined action alist.
- Docs: define the caller's ACTION; state the values of
  `disbuf-pivot-action-select` and
  `disbuf-pivot-other-window-prefix-select`; state that a dispatch
  action replaces the default window choice in either prompt; state
  that a caller-list run that returns nil prompts again or aborts;
  report the source of `inhibit-same-window` in caller intent info.
- Docs: sync the design with the input rule: state that
  `display-buffer-full-frame` delegates to the reuse, same-window,
  pop-up-window, and use-some-window functions and their entries apply;
  mark its matrix Decision as Regulate; correct the `buffer-match-p`
  conditions; state that the window prompt labels the windows it covers
  and the dispatch prompt shows caller intent info; reject "fallback
  line", "placement entry", and "caller action"; state that a constraint
  is an entry, not a class, and that only caller entries can be caller
  constraints; add the caller-list run to the window-settings opt-out
  definition.
- Docs: define abort as ending the display without running the later
  functions in the caller's ACTION; define the nil choice and its nil
  return; state that a nil display primitive reports with `message` and
  returns `fail`, and an error propagates or is re-signaled; rename the
  test "aborted choice" to "nil choice".
- Docs: state that caller intent info reports the entries the rule
  reads from the combined action alist and names the action that
  supplies an entry when it is not the caller's ACTION; apply the
  source naming to the window-setting effects and the same-window
  conflict.
- Docs: key the rule rows by the caller's first function; fold the
  generic reuse row into the no-preference and reuse rows; state the
  no-preference order (reuse, selected window, prompt); the
  cross-cutting entries follow section 8; add the atom window row and
  remove the duplicate `inhibit-same-window` case.
- Docs: define the decision order and the rule that selects the prompt:
  the window prompt with more than one eligible window, the dispatch
  prompt with one, and the dispatch prompt with no eligible window when
  it offers a dispatch action; otherwise the action returns nil.  The
  window prompt labels the windows it covers and marks undisplayable
  windows as ineligible.
- Docs: define the display input: the caller's ACTION supplies the
  intent class, and the combined action alist supplies the entries the
  first function's rule reads; an entry does not move the call to
  another class by itself; add the special action and the extra action
  to the combined action alist definition.
- Docs: regulate `display-buffer-full-frame`; the full-frame action is
  explicit, normal window labels do not delete windows, and the tab and
  frame actions override the intent.
- Docs: put the Regulate action functions before the Respect action
  functions in the action function table.
- Docs: describe action function fallbacks; every function receives the
  same combined action alist, a nil return falls through, and an error
  does not; the window-settings opt-out is local to the display call.
- Docs: add the "Display without caller window settings" action; name
  window-setting effects in caller intent info; remove every association
  of each window-setting key for the display call.
- Docs: group action alist entries by role; state the treatments for
  `dedicated`, the size entries, and `body-function`.
- Docs: define selection entries, window-setting entries, and the
  window-settings opt-out; reject bare "the opt-out".
- Docs: replace "merged alist" with "combined action alist" and "flow"
  with "placement path".
- Test: name the child-frame parent-frame check after the prefix
  commands.
- Docs: redefine pivot as the decision point; define target and
  placement path; replace "target behavior" with "intended behavior"
  and "target flow" with "placement path".
- Docs: define "failure after the choice" and use it for the post-choice
  display cases.
- Docs: reject "failed interactive display" and name the failure cases.
- Docs: align the window terms as **displayable window**, **can
  display** and **undisplayable window**, **cannot display**; use the
  noun form for windows.
- Docs: complete the test matrix for the new options, constraints, and
  excluded buffer.
- Docs: name the `disbuf-pivot-action-functions` default and option.
- Docs: replace stale prompt wording; name the window prompt and the
  other-frame prefix order.
- Docs: make new-target tab and frame actions start a new target and
  never select an existing one.
- Docs: reserve nil returns for the cannot-prompt and Respect cases; a
  failure after the choice while the package can prompt prompts again
  or aborts instead of running caller fallbacks.
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
  its own tab; the prefix commands search the parent frame of a child
  frame.
- Doc: the package and repository are `disbuf-pivot`; the source URL
  headers name the repository, and the README and codification describe
  the behavior and terms.
