# DESIGN_RULESET

This file is the design authority for `disbuf-pivot`.  It describes the
intended behavior; the source does not yet implement all of it.
`docs/DOCUMENTATION_CONVENTION.md` is the authority for terms and
documentation; `docs/GIT_CONVENTION.md` for commits;
`docs/CHANGELOG_CONVENTION.md` for changelog entries.  Define a term
there, not here.

The Emacs 31.1 action matrix used to check sections 7 and 8 is
`docs/DISPLAY_BUFFER_MATRIX.md`; it is a reference, not normative.

## 1. Goal and scope

`disbuf-pivot` replaces an implicit `display-buffer` choice with an
explicit one.  It aims for predictable display management, zero
surprises, and an explicit choice for the user.

The package is a policy layer.  It may call Emacs action functions as
the display primitive, but the target choice and the prompt remain the
package's.

Full coverage means:

- every `display-buffer` call that reaches the package's
  `display-buffer-alist` entry;
- the package prefix commands;
- the tab prompt and frame prompt used by those commands.

Full coverage does not mean every buffer-switching command.  It does not
include `switch-to-buffer`, completion previews, timers, process
filters, or calls handled by `display-buffer-overriding-action` or an
earlier `display-buffer-alist` entry.  `switch-to-buffer` remains
default; it obeys the display rules only when
`switch-to-buffer-obey-display-actions` is non-nil.

`column-popup` owns the buffers it declares; `disbuf-pivot` handles the
remaining buffers.  The intended order is `column-popup` first,
`disbuf-pivot` second.  Both packages cons at the front when their mode
is enabled, so the user enables `disbuf-pivot` first, then
`column-popup`.  The package does not force an order.  Anything that
should take precedence must be enabled after the package.

Zero surprises means the user sees caller intent info and the intended
choice when the dispatch prompt chooses the placement, the placement is
explicit, and noninteractive calls do not prompt.  Predictable means
the same intent, window state, and options produce the same target or
the same dispatch prompt; there is no hidden cache.

## 2. Terms

Package-specific terms are defined in
`docs/DOCUMENTATION_CONVENTION.md`.  Emacs's terms are used as they
are.

## 3. Intent classes and eligibility

The package reads two inputs:

- the caller's ACTION: its first function is the intent class; its later
  functions are the caller's fallbacks;
- the combined action alist: the entries the first function's rule
  reads, the eligibility constraints, and the window settings.  The
  combined action alist includes the caller's ACTION alist and entries
  from the overriding action, the matching `display-buffer-alist` entry,
  the special action, the extra action, `display-buffer-base-action`,
  and `display-buffer-fallback-action`.  The first association of a key
  wins.

The condition of the package's `display-buffer-alist` entry receives
the caller's ACTION; its action function receives the combined action
alist.

An entry in the combined action alist does not move the call to another
class by itself.  The first function's rule names the entries it reads.
For example, `display-buffer-reuse-window` reads `pop-up-frames` as a
frame scope, not as a frame target; a top-level `parent-frame` is not
read by `display-buffer-pop-up-frame` or `display-buffer-in-child-frame`
(the latter reads `parent-frame` inside `child-frame-parameters`).

The package distinguishes these classes:

- **names a place** -- a first function whose rule reads an entry as a
  fixed place: `display-buffer-in-side-window` (`side`, `slot`),
  `display-buffer-in-atom-window` (`window`, `side`), and
  `display-buffer-in-child-frame` (`child-frame-parameters`, including a
  `parent-frame` entry naming a top-level or child frame).  Respect the
  caller's placement; do not prompt unless the user invoked a prefix.
- **names a tab or frame** -- a tab or frame action and the entries its
  rule reads: `tab-name`, `tab-group`, `reusable-frames`,
  `ignore-current-tab`, `pop-up-frame-parameters`, `frame-predicate`,
  and `pop-up-frames` where the rule selects a frame.  Regulate the tab
  or frame choice: prompt with the tab prompt or frame prompt.  An
  existing-target action preselects an existing tab or frame; a
  new-target action starts a new one and does not select an existing
  target.  The tab prompt offers the tabs of its scope (section 6);
  `display-buffer-in-tab` adds every tab in the frames named by
  `reusable-frames` that already displays the buffer as a candidate,
  and does not add the other tabs of those frames.  A reusable tab is a
  candidate, not a silent selection.  Child frames are not targets; the
  tab prompt does not offer them.
- **names a relative placement** -- `display-buffer-in-direction`
  (`direction`, `window`), `display-buffer-below-selected`, and
  `display-buffer-at-bottom`.  Regulate like direction: show caller
  intent info, prompt by the rule in section 6, and offer a dispatch
  action that calls the caller's function.
- **names a strategy** -- same-window, reuse, other-window, new-window,
  use-some-window, use-least-recent-window, previous window, full-frame.
  Regulate the display by the rules below.
- **names no display** -- `display-buffer-no-window` with
  `allow-no-window`; call `display-buffer-no-window` and return `fail`
  (section 4).
- **no preference** -- follow the default order of
  `disbuf-pivot-action-functions`: reuse a window that displays the
  buffer, use the selected window when it can display, then prompt.

A constraint or a window-setting entry is an action alist entry the
rule reads, not a class.  `reusable-frames`, `previous-window`,
`frame-predicate`, `window-min-width`, and `window-min-height` are
constraints; honor them.  `inhibit-switch-frame` is honored where the
action function reads it; it does not limit the candidate windows.
`allow-no-window` permits the leave-undisplayed outcome (section 4).

`display-buffer-in-child-frame` takes `parent-frame` from
`child-frame-parameters`; a top-level `parent-frame` entry is not read.
The value may name a top-level frame or a child frame.  The package's
own frame prompt offers top-level frames only.

The package decides in this order:

1. An excluded buffer is not regulated; return nil.
2. In a context in section 9 where the package cannot prompt, return
   nil.
3. Read the first function of the caller's ACTION.  An ACTION with no
   function is no preference; ACTION `t` is an other-window request
   (section 4).  A first function that is `Respect` or not covered
   returns nil; the later functions in Emacs's combined function list
   run.  A first function that is `Regulate` uses its class rule.
4. The class rule reads the entries it names from the combined action
   alist.  An entry it does not name does not change the class.
5. The class rule shows the dispatch prompt when it says so and
   displays the buffer; the prompt follows section 6.  A nil choice, a
   failure after the choice, and C-g follow section 9.

A caller's ACTION may name several functions.  The first function is
the caller's primary intent; the later functions are the caller's
fallbacks.  Caller intent info names the chain: "Caller asks for X;
fallback Y."

When the rule shows the dispatch prompt, the intended choice is "Use
caller intent" when the caller's ACTION can run; the dispatch prompt
shows it with a key.  Choosing it runs the caller's whole function list
in order with the combined action alist, under a guard that prevents
the package's `display-buffer-alist` entry from running again.  The
action is in the Caller intent group.  The package does not regulate a
later function; it remains a later function in the caller's ACTION.
If the package cannot prompt (section 9), it returns nil and Emacs
continues with the later functions in its combined function list; the
caller's later functions are fallbacks.  A failure after the choice
while the package can prompt is handled by showing the dispatch prompt
again or aborting; it does not return nil to the caller's ACTION
functions.  Emacs calls every function in its combined list with the
same combined action alist; a function that returns nil passes to the
next, and an error propagates.
The package's run of the caller's function list for "Use caller intent"
follows the same nil and error rule.  If every function in that run
returns nil, the package shows the dispatch prompt again or aborts; it
does not return nil to the caller's ACTION functions.  A window-setting toggle changes the combined action alist
only for the package's display call and for a run of the caller's
function list from that prompt; it does not change the alist Emacs
passes to a later function in the caller's ACTION after the package
returns nil.  Do not reorder or deduplicate the list.  Use the first
association of an alist key, as Emacs does.

A package prefix command is user intent, not caller intent.
`disbuf-pivot-prefix-mode` remaps the built-in prefix commands to the
package prefix commands.  The package prefix commands keep the same
override for the next command, so they take precedence over the
caller's ACTION; they make the target explicit and predictable.
Section 6 gives the placement path and the intended choice for the
target window.

The selected window cannot display a buffer when it is a minibuffer
window, is dedicated to another buffer, is a side window, or is not
live.  `inhibit-same-window` is shown in caller intent info; it is not
one of these eligibility conditions.

When the user chooses the selected window despite
`inhibit-same-window`, the user's choice wins.  The dispatch prompt's
label for the selected window is eligible.  Bind that entry to nil for
the display call; caller intent info reports the non-selected-window
request and names the action that supplies the entry when it is not the
caller's ACTION.

## 4. Rules

Section 6 gives the rule.  The class rows are keyed by the caller's
first function; no function is no preference.  An entry the rule reads,
such as `inhibit-same-window` or a window-setting entry, follows
section 8 in addition to the row.  The no-preference rows follow the
default order of `disbuf-pivot-action-functions`; a reordered list
changes the order.  When a row shows the dispatch prompt, the Behavior
cell names the intended choice; "no intended choice" means the prompt
has no default key, so the user chooses a label, an action, or the
cancel key.

Every dispatch prompt labels every window in the selected tab or frame.
When a Behavior cell lists split actions and cancel, the prompt also
labels the windows.  "No intended choice" does not mean the prompt has
no window labels.

| Case | Behavior | Caller intent info |
|---|---|---|
| Same-window, selected window can display | Use the selected window; no prompt | None |
| Same-window, selected window cannot display | The dispatch prompt; no intended choice; offer split actions and cancel | "Caller asks for same window; selected window cannot display" |
| Same-window plus `inhibit-same-window` | Report the conflict; `disbuf-pivot-same-window-conflict` chooses the same window or shows the dispatch prompt; the intended choice is the same window; choosing it binds `inhibit-same-window` to nil | Conflict message |
| No preference, a window displays the buffer | Reuse the preferred window; `disbuf-pivot-reuse` can ask with the dispatch prompt; the intended choice is the preferred reuse window | "Reuse; window(s) X display the buffer" when it asks |
| No preference, no window displays and the selected window can display | Use the selected window; no prompt | None |
| No preference, no window displays and the selected window cannot display | The dispatch prompt; no intended choice; offer split actions and cancel | "Selected window cannot display the buffer" |
| Reuse intent, a window displays the buffer | Reuse it; `disbuf-pivot-reuse` chooses auto or ask; ask marks every reuse window and shows the dispatch prompt; the intended choice is the preferred reuse window | "Reuse; window(s) X display the buffer" when it asks |
| Reuse intent, no window displays the buffer | The dispatch prompt; no intended choice; offer split actions and cancel | "Reuse; no window displays the buffer" |
| Use some window | The dispatch prompt; the intended choice is "Use caller intent" (the caller's ACTION); labels and split actions override; show caller intent info | "Caller asks for some window" |
| Use least recent window | The dispatch prompt; the intended choice is "Use caller intent" (the caller's ACTION); the selected window's label is ineligible; labels and split actions override; show caller intent info | "Caller asks for a recently unused window" |
| Full frame | Show caller intent info; the dispatch prompt; the intended choice is "Display full frame"; a window label displays normally; offer tab/frame, split, and cancel | "Caller asks for the full frame; other windows will be deleted" |
| Other-window | The dispatch prompt; the intended choice is "Use caller intent" (the caller's ACTION); the selected window's label is ineligible; offer split actions and cancel | "Caller asks for other window" |
| New-window | The dispatch prompt; the intended choice is "Use caller intent" (the caller's ACTION); existing windows' labels are ineligible; offer split and new-frame actions and cancel | "Caller asks for new window" |
| Direction | The dispatch prompt; the intended choice is "Use caller intent" (the caller's ACTION); labels and actions override; leave side windows as-is | "Caller asks for direction X" |
| Below-selected / at-bottom | The dispatch prompt; the intended choice is "Use caller intent" (the caller's ACTION); labels and actions override; leave side windows as-is | "Caller asks for a window below the selected window" or "at the bottom of the frame" |
| Previous window | The dispatch prompt; the intended choice is "Use caller intent" (the caller's ACTION); show the named `previous-window` as the preferred candidate, or mark the windows that previously showed the buffer; use `disbuf-pivot-reuse` when no previous window is usable | "Caller asks for previous window X" or "Caller asks for a window that previously showed the buffer" |
| Tab or frame action | The other-frame prefix prompts frame, then tab when needed, then the window with the dispatch prompt.  A caller's tab or frame action prompts with the tab prompt or frame prompt; an existing target then shows the dispatch prompt, whose intended choice is the window that displays the buffer in the target, else the target's selected window; a new target uses its selected window.  An existing-target action preselects an existing tab or frame; a new-target action starts a new one and does not select an existing tab or frame with the same name | "Caller asks for existing tab/frame X" or "Caller asks for a new tab/frame" |
| Placed `child-frame-parameters` (including a `parent-frame` entry) | Respect the caller's placement; no prompt | Optional |
| Atom window | Respect the caller's placement; no prompt | Optional |
| Side window | Leave the caller's side placement as-is; no prompt | Optional |
| ACTION `t` | Treat as an other-window request; the selected window's label is ineligible; the dispatch prompt; the intended choice is the other-window request | "Caller asks for other window" |
| Caller ACTION with several functions | Classify the first function; later functions are the caller's fallbacks.  The intended choice is "Use caller intent"; it runs the whole list in order when the user chooses it | "Caller asks for X; fallback Y" |
| No display | With `allow-no-window`, call `display-buffer-no-window`; return `fail` | "No window requested" |
| Excluded buffer | Return nil; the later functions in Emacs's combined function list run | None |
| Anything not covered | Return nil; the later functions in Emacs's combined function list run | Optional |
| `switch-to-buffer` | Default; it obeys the rules only with `switch-to-buffer-obey-display-actions` | None |

## 5. Options and defaults

- `disbuf-pivot-reuse` -- `auto` (default) or `ask`.  It applies when
  a window already displays the buffer, and to the previous-buffer
  candidates of `display-buffer-in-previous-window`.  When it asks, the
  dispatch prompt shows the preferred reuse window as the intended
  choice.
- `disbuf-pivot-same-window-conflict` -- `ask` (default) or
  `same-window`.  It applies when the caller asks for the same window
  and sets `inhibit-same-window`.  When it chooses the same window,
  bind `inhibit-same-window` to nil for the display call.  When it
  asks, the dispatch prompt menu shows the same window as the intended
  choice; choosing it binds `inhibit-same-window` to nil.
- `disbuf-pivot-action-functions` -- the action functions the package's
  `display-buffer-alist` entry tries, in order.  The default is
  `display-buffer-reuse-window`, `display-buffer-same-window`, and
  `dp-action-choose-window`; it does not include an automatic split.
- `disbuf-pivot-caller-intent-info` -- non-nil (default) shows caller
  intent info in the dispatch prompt.  Silent selected-window defaults
  show no info.  Nil hides caller intent info in the dispatch prompt.
  It names the action that supplies an entry when it is not the
  caller's ACTION.
- `disbuf-pivot-exclude-conditions` -- nil (default) or a list of
  `buffer-match-p` conditions.  A matching buffer is not regulated: the
  package's `display-buffer-alist` entry returns nil and the later
  functions in Emacs's combined function list run.  A condition can
  match the buffer name (a regexp), a major mode
  (`(derived-mode . MODE)` or `(major-mode . MODE)`), a category
  (`(category . SYMBOL)`), or a predicate function; `not`, `and`, and
  `or` combine conditions.
- `disbuf-pivot-action-select` -- `auto` (default), `t`, or `nil`.
  `t` selects the chosen window; `auto` leaves selection to the caller;
  `nil` selects nothing and restores the window selected before the
  action at the end of the command.  It controls selection after the
  dispatch prompt.
- `disbuf-pivot-other-window-prefix-select` -- `auto` (default), `t`,
  or `nil`.  It has the same values and effects after the other-window
  prefix.
- `disbuf-pivot-tab-prompt-scope` -- nil (default), `t`, `visible`, or
  `0`.  The default for the tab prompt scope outside the pivot: nil for
  the selected frame, `t` for all existing frames, `visible` for the
  visible frames, and `0` for all frames on the current terminal.  The
  reader's scope argument also accepts a frame.  Outside the pivot, the
  tab prompt uses the user option as its default; at the pivot, its
  scope is the selected frame, and the reusable tabs from other frames
  are candidates, not part of the scope.  The user option applies only
  outside the pivot.

C-g always aborts; there is no option for it.

Automatic split is not part of the core.  Split actions are user
choices in the prompt.  `disbuf-pivot-window-utility-split-p` and its
options are not consulted by the core behavior.

Frame preview is not part of the first implementation.  The tab preview
with consult remains optional.

The dispatch prompt draws the labels on every window in the selected
tab or frame.  The label of an eligible window acts; the label of an
ineligible window states why it is ineligible and keeps the prompt open.
The prompt draws the label of an eligible window with
`disbuf-pivot-eligible-label` and the label of an ineligible window with
`disbuf-pivot-ineligible-label`.  The Windows group repeats the keys and
faces; it does not repeat the reason.

## 6. Interaction rules

- When a rule shows the dispatch prompt, the prompt labels every window
  in the selected tab or frame.  The label of an eligible window acts;
  the label of an ineligible window states why it is ineligible and
  keeps the prompt open.  The prompt shows the intended choice with a
  key.  When the rule has no target or action that can run, the prompt
  has no intended choice; the window labels, the split actions, and the
  cancel key remain.  A split action splits the selected window; the cancel key
  returns nil (a nil choice).
- The dispatch prompt has two parts: the window labels drawn on the
  windows and the dispatch prompt menu.  The dispatch prompt menu is not
  a transient menu: the action function reads its keys and does not
  return to `display-buffer` until the user chooses.  A transient prefix
  command
  returns before the choice; the package does not call one.  The
  dispatch prompt draws the labels on every window in the selected tab
  or frame: the label of an eligible window uses
  `disbuf-pivot-eligible-label`; the label of an ineligible window uses
  `disbuf-pivot-ineligible-label` and states why it is ineligible.  The
  Windows group repeats the keys and faces; it does not repeat that
  reason.  The package computes the windows before the dispatch prompt
  menu is shown and does not label the dispatch prompt menu window.
  That window is a side window; the package's `display-buffer-alist`
  entry returns nil for its side-window action.  The dispatch prompt
  menu shows a window-setting toggle for each window-setting entry
  present in the combined action alist, and the window-settings group
  toggle when at least one window-setting entry is present.  The action
  function reads the keys for the window labels, the dispatch actions,
  and the toggles; the package does not call `aw-select` or a transient
  prefix command.  A
  window-setting toggle or the group toggle keeps the dispatch prompt
  menu open; a label, an action, or the cancel key ends the dispatch
  prompt menu and the action function returns; C-g aborts.
- The dispatch action list groups the actions:
  - **Split**: the split actions from `aw-dispatch-alist`, with their
    keys and descriptions.
  - **Caller intent**: "Use caller intent" when the caller's ACTION has
    a function or functions, and any action the rule offers from the
    caller's ACTION, named by its user-facing action, not by the raw
    function.
  - **Other**: a new frame for a new-window intent; leave undisplayed
    only with `allow-no-window`; the cancel key.
  The window-setting toggles and the window-settings group toggle are
  not dispatch actions; they are in the window-settings group.  The window labels
  are not dispatch actions; they are in the compact Windows group with
  the same keys and faces.  From `aw-dispatch-alist`, the dispatch action
  list takes only the split actions; the user's other actions are not
  offered.
- The keys in `aw-keys` and `aw-dispatch-alist` win.  Window labels use
  the `aw-keys` keys that do not collide with `aw-dispatch-alist`.  The
  package's dispatch actions use Meta-letter defaults.  Window-setting
  toggles use fixed Meta-digit defaults: `M-1` dedicated, `M-2`
  window-parameters, `M-3` preserve-size, `M-4` window-height, `M-5`
  window-width, `M-6` window-size, and `M-0` for the group.  An absent
  entry has no toggle, and its key is not reused.  A dispatch prompt key
  the package supplies for a dispatch action or a window-setting toggle
  is offered only when it does not collide with a key from `aw-keys` or
  `aw-dispatch-alist`, a window label, or another such key; if a default
  collides, use the next free key of the same kind.
- The dispatch prompt menu header is above the three horizontal menu
  groups: the Windows group, the dispatch action group, and the
  window-settings group.  The labels remain visible on the windows, and
  the dispatch action list is not hidden behind `?`.
- The caller intent info and the intended choice form the
  dispatch prompt menu header above the groups.  The info is one line
  and is a concise summary.  It names the primary intent, the caller's
  fallback chain, and the combined action alist entries the current rule
  reads that affect the choice or the chosen window.  It names effects
  and sources, not raw entries;
  the window-settings group shows when each entry applies.  It does not
  name controls, entries the rule does not read, or the combined
  function list.  `body-function` is not named.
- The dispatch prompt menu header names the source of an entry that is not
  from the caller's ACTION.  In the dispatch prompt menu header,
  `display-buffer-base-action` is "base action",
  `display-buffer-overriding-action` is "overriding action", and
  `display-buffer-fallback-action` is "fallback action"; the special
  action and the extra action are named as they are.  Use the full
  variable names everywhere else.  The matching `display-buffer-alist`
  entry supplies no action alist entries when the prompt shows: it is
  the package's entry, and its action alist is nil.
- Example: "Caller: direction right, a 20-line window, preserve size;
  base action: dedicated."  The window-settings group shows when each
  entry applies: height and dedication are "new windows only"; preserve
  size has no restriction.
- The dispatch prompt menu shows a window-setting toggle for each
  window-setting entry present in the combined action alist with the
  fixed keys above; the toggle shows the entry's source, state, and when
  it applies.  An absent entry has no toggle.
- A window-setting toggle removes or restores every association of one
  window-setting entry's action alist key in the combined action alist
  for the package's display call and for a run of the caller's function
  list from that
  prompt.  The toggle stays available while the dispatch prompt is
  open; toggling it does not close the prompt.  It leaves every
  non-window-setting entry unchanged, including selection entries,
  `body-function`, `post-command-select-window`, `bump-use-time`, and
  `inhibit-switch-frame`.  It does not change the caller's ACTION.  It
  is local: if the package returns nil, Emacs's later action functions
  receive the original combined action alist.  The display call and a
  run of the caller's function list for "Use caller intent" use the
  modified alist.
- The window-settings group toggle is shown when at least one
  window-setting entry is present.  It removes every window-setting
  entry if any window-setting entry is active; if all are removed, it
  restores every window-setting entry to its value in the combined
  action alist at prompt start.  Its state is on, off, or mixed; with
  one window-setting entry it has the same effect as that entry's
  toggle.  It keeps the prompt open, and the local-scope rule above
  applies to it.
- For a full-frame intent, caller intent info says "Caller: full frame;
  other windows will be deleted."  The dispatch prompt
  shows "Display full frame" as the intended choice.  Add "Display in
  another or new tab" (when `tab-bar-mode` is active) and "Display in
  another or new frame" to the Other group.  "Display full frame"
  deletes the other windows; a window label displays normally without
  that deletion; a split, tab, or frame action displays another way; the
  cancel key returns nil.  The caller's full-frame action remains part
  of the caller's ACTION: its nil or error is not a failure after the
  choice.
- The package checks `disbuf-pivot-exclude-conditions` in the
  condition of its `display-buffer-alist` entry.  A matching buffer
  returns nil; no prompt runs, and the later functions in Emacs's
  combined function list run.
  `display-buffer-overriding-action` and earlier
  `display-buffer-alist` entries still take precedence.
- C-g aborts the display; it does not run the caller's fallbacks.  The
  "Use caller intent" action is the explicit way to run the chain.
- The Other group offers a leave-undisplayed dispatch action only when
  `allow-no-window` is non-nil.  The cancel key is always available.
- A split action ends the dispatch prompt.  If the split action fails,
  show the error and show the dispatch prompt again.
- Selection follows `disbuf-pivot-action-select`: `auto` leaves it to
  the caller, `t` selects the chosen window, and `nil` restores the
  window selected before the action at the end of the command.
- Frame focus and raising use the standard action functions and honor
  `inhibit-switch-frame`.
- For the other-frame prefix, the order is frame, then tab when needed,
  then the window with the dispatch prompt.  The intended choice is the
  window that displays the buffer in the target, else the target's
  selected window.  A new frame uses its selected window.  Skip the tab
  prompt for a new frame, and for a frame with one tab unless
  `tab-bar-mode` is active.
- The tab prompt offers the tabs of its scope: nil for the selected
  frame, `t` for all existing frames, `visible` for the visible frames,
  `0` for all frames on the current terminal, or a frame for that frame.
  Child frames are not offered.  The reader takes an optional scope;
  outside the pivot, the tab prompt uses
  `disbuf-pivot-tab-prompt-scope` as its default; at the pivot, its
  scope is the selected frame, and the reusable tabs from other frames
  are candidates, not part of the scope.  The user option applies only
  outside the pivot.  The prompt string is "Switch or create tab:" for
  the selected frame; for another scope it appends the scope before the
  colon: "(all frames)" for `t`, "(visible frames)" for `visible`,
  "(current terminal)" for `0`, and "(frame NAME)" for a frame.
- `display-buffer-in-tab` adds every tab in the frames named by
  `reusable-frames` that already displays the buffer to the tab prompt
  as a candidate.  It does not add the other tabs of those frames.
  Choosing the candidate selects its frame and the tab; no frame prompt
  runs for the choice.  When several tabs display the buffer, all are
  candidates; the intended choice is the tab the caller's function
  would select, following `ignore-current-tab`.
- The tab candidate annotation shows the frame when the prompt offers
  tabs in more than one frame.  A name that matches no tab the prompt
  offers is a tab history candidate; the prompt marks it `(closed)`.
  The package supplies the annotation, not Marginalia.
- The consult tab reader does not preview a candidate whose tab is
  outside the selected frame and does not switch frames during
  completion.  The plain tab reader has no preview.  The buffer column
  of the tab candidate annotation shows the candidate's buffers.
- When the package selects or makes a tab, it enables `tab-bar-mode` if
  `tab-bar-show` is non-nil and the mode is off; it does not enable it
  when `tab-bar-show` is nil.  This applies to the other-tab prefix, a
  caller's `display-buffer-in-tab` or `display-buffer-in-new-tab`, the
  frame prompt's tab step, and a reusable tab chosen in the tab prompt.
  `tab-bar-new-tab` already enables
  the mode for a new tab (`tab-bar.el:2144–2148`); the package does the
  same for an existing tab, so the layout switch shows the tab bar.
  Once the mode is on, the frame prompt's tab step runs for an existing
  frame even when the frame has one tab; a new frame still uses its
  selected window.
- An existing-target action preselects an existing tab or frame; a
  new-target action starts a new one and must not select an existing
  tab or frame with the same name.  The prompt string states the
  caller's intention; the dispatch prompt, when there is one, shows it
  in caller intent info.
- Reuse caller intent info names the qualifying windows.  Same-window
  and no-preference info is optional.
- The same-window conflict message states which request is the
  caller's and which entry conflicts, naming the action that supplies
  the entry when it is not the caller's ACTION, then applies
  `disbuf-pivot-same-window-conflict`.  When the option asks, the
  dispatch prompt menu's intended choice is the same window; choosing it
  binds `inhibit-same-window` to nil.
- Direction uses `display-buffer-in-direction` for the intended choice.
  Below-selected and at-bottom use their own functions for the intended
  choice.  Side windows are left as-is.
- The four package prefix commands are remapped: same-window,
  other-window, other-tab, and other-frame.  The next subsection gives
  their placement paths and intended choices.

### The package prefix commands

A package prefix command is user intent, not caller intent: it sets the
target for the next command, and the caller's ACTION is not the
intended choice.

| Prefix | Frame prompt | Tab prompt | Dispatch prompt | Intended choice |
|---|---|---|---|---|
| same-window | No | No | Only if the selected window cannot display | None; the selected window is used when no prompt runs; the dispatch prompt has no intended choice |
| other-window | No | No | Yes | The prefix's other-window request |
| other-tab | No | Yes | Yes for an existing tab; no for a new tab (its selected window) | The window displaying the buffer in the chosen tab, else its selected window |
| other-frame | Yes | Yes for an existing frame when `tab-bar-mode` is active or the frame has more than one tab; no for a new frame | Yes for an existing tab; no for a new tab (its selected window) | The window displaying the buffer in the chosen tab, else its selected window |

Read each row left to right; `No` skips that prompt, and a conditional
cell says when it runs.  The other-tab prefix always shows the tab
prompt; only the other-frame prefix's tab step is gated on
`tab-bar-mode` or more than one tab.

```text
same-window
  → selected window
  ↳ if the selected window cannot display → dispatch prompt

other-window
  → dispatch prompt

other-tab
  → tab prompt
    ├ existing tab → dispatch prompt
    └ new tab      → its selected window

other-frame
  → frame prompt
    ├ existing frame → tab prompt
    │                  (when tab-bar-mode is active or the frame has
    │                   more than one tab)
    │                  ├ existing tab → dispatch prompt
    │                  └ new tab      → its selected window
    └ new frame      → its selected window
```

For the same-window prefix, use the selected window when it can
display.  When it cannot, show the dispatch prompt, make the selected
window's label ineligible when it is in that tab or frame, and leave
the prompt without an intended choice; its split actions and cancel key
remain.

For the other-window prefix, show the dispatch prompt, label every
window in the selected tab or frame, and make the selected window's
label ineligible when it is in that tab or frame.  Split actions are
prompt choices, not automatic.  The intended choice is the prefix's
other-window request, not "Use caller intent"; the caller's ACTION may
still appear in the Caller intent group when it can run.  The info line
states the user's request, not the caller's ACTION.  The prefix follows
`reusable-frames` and ignores the selected window for the display.
Selection follows `disbuf-pivot-other-window-prefix-select`.

The other-tab and other-frame prefixes follow the tab or frame action
placement path: an existing tab or frame chosen by the prompt shows the
dispatch prompt; a new tab or frame uses its selected window.  An
existing tab or frame that already displays the buffer still shows the
dispatch prompt, with that window as the intended choice.  Failure
after the choice follows section 9.  Selection after a dispatch prompt
follows `disbuf-pivot-action-select`; a prefix that shows no dispatch
prompt leaves selection to the caller.

The other-tab prefix uses the selected frame as the tab prompt scope;
the other-frame prefix's tab step uses the chosen frame.  Neither
prefix reads `disbuf-pivot-tab-prompt-scope`.  A next command's tab
action that reads `reusable-frames` adds its reusable tabs to the
prompt.

When the selected frame is a child frame, the prefix commands use the
parent frame for the dispatch prompt.  Child frames are not targets;
the frame prompt offers top-level frames only.

## 7. Action function checklist

`Regulate` means the package handles the display under its own rules:
it shows caller intent info and the intended choice, prompts when
needed, lets the user choose a target or a dispatch action, and
displays the buffer in the chosen window.  Calling an Emacs action
function is the display primitive, not a delegation of the regulation.

`Respect` means the package returns nil without displaying; the later
functions in Emacs's combined function list run.

The table describes a caller's ACTION that names the function.  A
package prefix command or a user choice in a prompt is separate; the
package may call the same function after that choice.

The table applies when the function is the first function in the
caller's ACTION.  A later function in the same ACTION is a caller
fallback; section 3 gives the rule for a list of functions.

The "Relevant alists" column lists the action alist entries the action
function reads.  Window-setting entries are shared by every action
function; section 8 handles them.  A selection entry is not applied to
the chosen window after the choice.

| Action function | Treatment | Relevant alists |
|---|---|---|
| `display-buffer-same-window` | Regulate.  When the selected window can display, its label is eligible; choosing it binds `inhibit-same-window` to nil for this call.  When it cannot display, the prompt offers the split actions and cancel. | `inhibit-same-window` |
| `display-buffer-reuse-window` | Regulate.  If the user chooses the selected window despite `inhibit-same-window`, bind that entry to nil for this call. | `inhibit-same-window`, `reusable-frames`, `inhibit-switch-frame`, `reuse-indirect` |
| `display-buffer-reuse-mode-window` | Regulate as reuse with `mode`. | `mode`, `inhibit-same-window`, `reusable-frames`, `inhibit-switch-frame` |
| `display-buffer-pop-up-window` | Regulate for a split action. | `inhibit-switch-frame`; shared window-setting entries (section 8) |
| `display-buffer-in-previous-window` | Regulate.  Show the `previous-window` entry as the preferred candidate; when it is not usable, mark the windows that previously showed the buffer. | `previous-window`, `inhibit-same-window`, `reusable-frames` |
| `display-buffer-use-some-window` | Regulate: show caller intent info; the dispatch prompt; the intended choice is "Use caller intent" (the caller's ACTION); a label or another action overrides.  Do not display without the prompt. | `some-window`, `lru-frames`, `lru-time`, `window-min-width`, `window-min-height`, `inhibit-same-window`, `inhibit-switch-frame` |
| `display-buffer-use-least-recent-window` | Regulate like `display-buffer-use-some-window`. | `reusable-frames`, `inhibit-switch-frame`, `lru-frames`, `lru-time`, `window-min-width`, `window-min-height`; `inhibit-same-window` is forced to t internally |
| `display-buffer-in-direction` | Regulate; the intended choice is "Use caller intent" (the caller's ACTION, `display-buffer-in-direction`). | `direction`, `window` |
| `display-buffer-below-selected` | Regulate; the intended choice is "Use caller intent" (the caller's ACTION).  `window-min-height` is an eligibility constraint. | `window-min-height` |
| `display-buffer-at-bottom` | Regulate; the intended choice is "Use caller intent" (the caller's ACTION). | None specific |
| `display-buffer-full-frame` | Regulate.  Show caller intent info; the dispatch prompt menu's intended choice is "Display full frame"; a window label displays normally; split, tab, and frame actions override; the cancel key returns nil | Delegates to `display-buffer-reuse-window`, `display-buffer-same-window`, `display-buffer-pop-up-window`, and `display-buffer-use-some-window`; their entries apply |
| `display-buffer-pop-up-frame` | Regulate for a new frame.  Ask for a new frame name; do not offer existing frames.  Use `pop-up-frame-parameters`; the new frame is top-level unless that entry sets `parent-frame`.  `pop-up-frames` selects the frame strategy but this function does not read it. | `pop-up-frame-parameters`, `inhibit-switch-frame` |
| `display-buffer-use-some-frame` | Regulate for an existing frame; `frame-predicate` filters the candidates. | `frame-predicate`, `inhibit-same-window`, `inhibit-switch-frame` |
| `display-buffer-in-tab` | Regulate.  The tab prompt offers the selected frame's tabs and every tab in the `reusable-frames` scope that displays the buffer; other tabs of those frames are not candidates.  Preselect the tab the function would select (the current tab first unless `ignore-current-tab`); a new tab starts without an existing-tab preselect. | `reusable-frames` (nil differs), `ignore-current-tab`, `tab-name`, `tab-group` |
| `display-buffer-in-new-tab` | Regulate; ask for a new tab name; do not select an existing tab with the same name. | `tab-name`, `tab-group` |
| `display-buffer-no-window` | Regulate: leave undisplayed; only with `allow-no-window`. | `allow-no-window` |
| `display-buffer-in-child-frame` | Respect. | `child-frame-parameters` (including a `parent-frame` entry naming a top-level or child frame), `inhibit-switch-frame` |
| `display-buffer-in-side-window` | Respect; side as-is. | `side`, `slot` |
| `display-buffer-in-atom-window` | Respect. | `side`, `window` |

## 8. Action alist checklist

The action alist entries have different roles.  The package passes the
combined action alist to the function it calls.  It does not drop an
entry silently.  It binds `inhibit-same-window` to nil when the user
chooses the selected window, and a window-setting toggle removes or
restores the window-setting entry it shows.

A **selection entry** limits, orders, or chooses the candidate window,
frame, tab, or placement, or the display outcome.  The package uses it
during the prompt; it is not applied to the chosen window afterward.
A **window-setting entry** changes the chosen window itself: its
dedication, parameters, or size.  The package preserves it and applies
it through the standard display path.  `body-function` is a body
function, not a window-setting entry; the package preserves it.

### Selection entries

| Entry | Treatment |
|---|---|
| `inhibit-same-window` | Show caller intent info; the dispatch prompt; the selected window's label is eligible; choosing it binds this entry to nil for the display call.  The user may choose another window or a dispatch action. |
| `previous-window` | Show the named window as the preferred candidate when it is displayable; do not force it.  Without a usable entry, mark the windows that previously showed the buffer. |
| `mode` | Pass to `display-buffer-reuse-mode-window` when reuse is regulated with a mode. |
| `frame-predicate` | Frame candidates; honor. |
| `reusable-frames` | Reuse and tab scope; honor.  The tab meaning of nil differs.  For `display-buffer-in-tab`, the frames are searched for a tab that displays the buffer; they do not add those frames' other tabs to the tab prompt. |
| `window-min-width`, `window-min-height` | Eligibility constraints; honor when choosing a window. |
| `some-window`, `lru-frames`, `lru-time` | Pass to `display-buffer-use-some-window` or `display-buffer-use-least-recent-window` when the package calls it; otherwise leave in the alist.  Do not apply them to the chosen window. |
| `reuse-indirect` | Pass to `display-buffer-reuse-window`. |
| `pop-up-frames` | Selects the frame strategy; `display-buffer-pop-up-frame` does not read it.  The reuse functions use it as the frame scope when `reusable-frames` has no entry. |
| `allow-no-window` | Allow the leave-undisplayed outcome. |

### Entries that name a place

| Entry | Treatment |
|---|---|
| `tab-name`, `tab-group`, `ignore-current-tab` | Tab placement; honor. |
| `direction`, `window` | Direction action; honor. |
| `side`, `slot` | Side placement; leave as-is. |
| `child-frame-parameters` (including a `parent-frame` entry naming a top-level or child frame) | Child-frame placement; respect. |
| `pop-up-frame-parameters` | New-frame parameters; honor. |

### Window-setting entries

| Entry | Treatment |
|---|---|
| `dedicated` | Preserve; apply through `window--display-buffer`.  A reused normal window is not dedicated; a new window receives the entry's value; a window already dedicated to this buffer and showing it keeps its flag; a window dedicated to this buffer but not showing it is reset to nil before display; a window dedicated to another buffer is undisplayable; its label is ineligible.  `display-buffer-in-side-window` is Respect and adds `(dedicated . side)` by default unless the alist already has a `dedicated` entry (`window.el:1120–1122`); the prompt labels a side window as ineligible.  Caller intent info names the effect; the window-settings group says "new windows only" and names the source.  A window-setting toggle removes the entry. |
| `window-parameters` | Preserve; apply to the chosen window.  Caller intent info names the effect "window parameters"; the window-settings group names the source.  A window-setting toggle removes the entry. |
| `preserve-size` | Preserve the chosen window's size; apply to any chosen window.  Caller intent info names the effect; the window-settings group has no restriction for it.  A window-setting toggle removes the entry. |
| `window-height`, `window-width` | Preserve; apply only when the window never showed another buffer (a new window on an existing frame).  Caller intent info names the effect; the window-settings group says "new windows only".  A window-setting toggle removes each entry. |
| `window-size` | Preserve; apply when the window is on a new frame.  Caller intent info names the effect; the window-settings group says "new frame".  A window-setting toggle removes the entry. |

### Other entries

| Entry | Treatment |
|---|---|
| `body-function` | Preserve; call after the buffer is displayed and before the size entries.  It is a body function, not a window-setting entry; it is not named in caller intent info and the window-setting toggles do not remove it.  A failure follows the failure-after-the-choice rule. |
| `post-command-select-window` | Honor; `disbuf-pivot-action-select` defaults to `auto`.  The toggles leave it. |
| `bump-use-time` | Handle through `window--display-buffer`.  The toggles leave it. |
| `inhibit-switch-frame` | Frame raising and focus; honor.  The toggles leave it. |
| `category` | Pass through; use it in caller intent info when present.  The toggles leave it. |

## 9. Contexts

The package cannot prompt in the batch, active-minibuffer, timer,
process-filter, keyboard-macro, and recursive-display contexts below.
In them none of the dispatch prompt, the tab prompt, or the frame
prompt runs; the action returns nil.

- Batch: return nil.  Do not prompt.
- Active minibuffer: return nil.  Do not prompt.
- Timer, process filter, or keyboard macro: return nil.  Do not prompt.
- Daemon or text terminal: the same prompt rules apply; the dispatch
  prompt may still work.
- Recursive display during tab or frame creation, or during a preview:
  return nil for the nested call.
- Multiple `display-buffer` calls in one command: no cache.
- Failure after the choice: if the chosen window is undisplayable
  because it is dead, show the dispatch prompt again; if it is
  undisplayable because its frame or tab is gone, prompt again with the
  frame prompt or tab prompt.  If the action function it calls returns
  nil, report it with `message` and return `fail`; if it signals an
  error, propagate or re-signal it.  A split action failure is separate:
  section 6 shows the error and shows the dispatch prompt again.  A
  `body-function` error is such a failure; it is not a window-setting
  entry and a window-setting toggle does not remove it.  Do not return
  nil to the caller's ACTION functions while the dispatch prompt can
  run.
- A nil choice: the prompt returns nil without C-g; the action returns
  nil; the later functions in Emacs's combined function list run.
- A nil return is reserved for the cannot-prompt contexts, the excluded
  buffer, the Respect or not-covered cases, and a nil choice; Emacs
  calls the later functions in its combined function list with the same
  combined action alist.  A window-setting toggle is local to the
  prompt and the package's display call.

## 10. Implementation tasks

1. Add the options in section 5 with the stated defaults.
2. Change the default action list: replace `dp-action-split-or-ask`
   with `dp-action-choose-window`; split actions are prompt choices
   only.
3. Classify the first function in the caller's ACTION; later functions
   are the caller's fallbacks.  Respect the classes in section 3; return
   nil for anything the package does not regulate.  The intended choice
   is "Use caller intent" when the caller's ACTION can run; it runs the
   caller's whole function list in order when the user chooses it.  A
   failure after the choice while the package can prompt is handled by
   showing the dispatch prompt again or aborting; do not return nil to
   the caller's ACTION functions.  A nil choice returns nil; it is not
   a failure after the choice.
4. Regulate same-window, reuse, other-window, new-window,
   use-some-window, use-least-recent-window, full-frame, direction,
   below-selected, at-bottom, previous window, and the tab and frame
   choices.  Use the tab prompt and frame prompt, then the dispatch
   prompt for the target window; an existing-target action preselects
   an existing tab or frame, and a new-target action starts a new one
   and does not select an existing target.  Keep the tab and frame
   placement paths of the package prefix commands.  Enable
   `tab-bar-mode` under `tab-bar-show` when the package selects or
   makes a tab.  Use the action functions in section 7 as the display
   primitives.
5. Handle `inhibit-same-window`: show caller intent info, show the
   dispatch prompt, keep the selected window's label eligible, and bind
   the entry to nil when the user chooses it.
6. Show the dispatch prompt menu header: caller intent info and the intended
   choice above the groups.  The info is a one-line summary of the
   primary intent, the fallback chain, and the entries the rule reads
   that affect the choice or chosen window; it names effects and
   sources, not when an entry applies; the window-settings group shows
   when each entry applies.  Use the dispatch prompt menu header source
   labels.  The dispatch prompt menu is not a transient menu; the
   action function reads its keys and does not return until the user
   chooses.  Do not call a transient prefix command.  Remove
   `disbuf-pivot-mode-line-help` and the former one-line hint string.
7. Make C-g abort.  Remove any option that changes C-g behavior.
8. Default selection to `auto`; honor `post-command-select-window`;
   keep `t` and `nil` as forcing options.
9. The dispatch prompt draws the labels on every window in the selected
   tab or frame and shows them in a compact Windows group with the same
   keys and faces.  The label of an eligible window acts; the label of an
   ineligible window states why it is ineligible and keeps the prompt
   open.  Lay the dispatch prompt menu header and the three menu groups
   out horizontally: the Windows group, the dispatch action group, and
   the window-settings group.  The prompt reads the keys for the labels,
   the dispatch actions, and the toggles; do not call `aw-select`.  Add
   `disbuf-pivot-eligible-label` and `disbuf-pivot-ineligible-label`.
10. Add the context guard from section 9.
11. Preserve the window-setting entries; name their effects in caller
    intent info and when each entry applies in the window-settings
    group; show a window-setting toggle for each present window-setting
    entry with its source, state, and when it applies; show the
    window-settings group toggle when at least one window-setting entry
    is present.  Use the fixed Meta-digit keys and `M-0` for the
    window-settings group toggle; user keys win.  A window-setting
    toggle removes or restores every association of its action alist key
    for the display call and for a run of the caller's function list
    from that prompt; the window-settings group toggle does so for every
    window-setting entry's action alist key.  Leave `body-function` and
    every other non-window-setting entry unchanged.
12. Regulate `display-buffer-full-frame` when it is the first caller
    function.  Show caller intent info; the dispatch prompt menu's
    intended choice is "Display full frame"; add the tab and frame actions to
    the Other group.  A window label displays normally; "Display full
    frame" deletes the other windows; the cancel key returns nil.
13. Add the tab prompt scope: the scope option and reader argument;
    the scope values and child-frame exclusion; the reusable tabs from
    `reusable-frames` as added candidates; the frame-aware selection;
    the frame column in the tab candidate annotation; the
    scope-relative tab history candidate; and no preview for a
    candidate outside the selected frame.
14. Add tests for every rule in section 4, every action function in
    section 7, every action alist entry in section 8, and every context
    in section 9.
15. Update `README.md` and `CHANGELOG.md` after the behavior is
    implemented.

## 11. Test matrix

Every rule needs a Buttercup test.  Combine:

- caller intent: same-window, no preference, reuse with a target, reuse
  without a target, other-window, new-window, use some window, use least
  recent window, full frame, direction, below-selected, at-bottom,
  previous window, existing tab, new tab, existing frame, new frame,
  placed, atom, side, ACTION `t`, no display (`allow-no-window`),
  excluded buffer, `switch-to-buffer`;
- no preference order: a window displays the buffer; no window displays
  and the selected window can display; no window displays and the
  selected window cannot display;
- caller ACTION: one function, several functions, all-Regulate,
  all-Respect, mixed, duplicate, empty, and an inapplicable first
  function;
- combined action alist: an entry from `display-buffer-base-action`,
  `display-buffer-overriding-action`, `display-buffer-fallback-action`,
  the special action, or the extra action that the rule reads affects
  eligibility or the info line and is named; an entry the rule does not
  read does not change the class;
- tab prompt and frame prompt: an existing-target action preselects an
  existing tab or frame; a new-target action starts a new one and does
  not select an existing one; the prompt string states the caller's
  intention;
- tab prompt scope: nil, `t`, `visible`, `0`, and a frame; child frames
  are excluded; the prompt string appends the scope suffix for `t`,
  `visible`, `0`, and a frame; outside the pivot, the tab prompt uses
  `disbuf-pivot-tab-prompt-scope`; at the pivot, its scope is the
  selected frame and the user option is not read;
- reusable tab: a tab in another frame is a candidate; that frame's
  other tabs are not; several matching tabs are candidates, with the
  function's choice as the intended choice; choosing the candidate
  selects its frame and the tab; no frame prompt runs;
- tab candidate annotation: the frame column appears when the prompt
  offers tabs in more than one frame; a name matching no offered tab is
  a tab history candidate, marked `(closed)`; the package supplies the
  annotation, not Marginalia;
- tab preview: with the consult tab reader, a candidate in the selected
  frame is previewed by selecting its tab, and a candidate in another
  frame has no preview; the plain tab reader has no preview; the buffer
  column shows its buffers;
- window state: selected window eligible, dedicated to another buffer,
  dedicated to this buffer, side, minibuffer, and dead; window already
  displaying the buffer or not;
- target state: existing, new, none;
- dispatch prompt: draws the labels on every window in the selected tab
  or frame and shows them in a compact Windows group with the same keys
  and faces; the label of an eligible window acts; the label of an
  ineligible window states why it is ineligible and keeps the prompt
  open; the Windows group does not repeat the reason; the two faces; the
  dispatch prompt menu header holds caller intent info and the intended
  choice; the dispatch prompt menu groups are laid out horizontally;
  the intended choice
  is shown with a key; the action function does not return before the
  choice; a transient prefix command is not called; the dispatch prompt
  menu stays open across a window-setting toggle; the dispatch prompt
  menu window is not labeled; the Windows group is not a dispatch
  action; the cancel key returns nil; the action function reads the
  window-label keys, the dispatch action keys, and the toggle keys;
  `aw-select` is not called;
- caller intent info: the dispatch prompt menu header is a one-line summary;
  it names the primary intent, the fallback chain, and the entries the
  rule reads that affect the choice or chosen window; it names effects
  and sources, not when an entry applies; the window-settings group
  shows when each entry applies; the source labels are "base action",
  "overriding action",
  and "fallback action", and the special and extra actions by name; the
  full variable names are used outside the dispatch prompt menu header; the
  matching `display-buffer-alist` entry supplies no source when the
  prompt shows;
  entries the rule does not read and `body-function` are not named;
- dispatch prompt key: the keys from `aw-keys` and `aw-dispatch-alist`
  win; a package-supplied key for a dispatch action or a window-setting
  toggle is offered only when free; a collision uses the next free key
  of the same kind;
- caller constraint: none, `inhibit-same-window`, `reusable-frames`,
  `previous-window`, `frame-predicate`, `window-min-width`,
  `window-min-height`;
- other entry: `inhibit-switch-frame`, `allow-no-window`;
- full frame: the dispatch prompt menu shows "Display full frame" as the
  intended choice; a window label displays normally; "Display full
  frame" deletes the other windows; "Display in another or new tab" is
  offered when `tab-bar-mode` is active; the frame action is offered;
  the cancel key returns nil; the caller's full-frame action's nil or
  error follows the caller's ACTION;
- window-setting entry: `dedicated` on a reused normal window, a new
  window, a window already dedicated to this buffer and showing it, a
  window dedicated to this buffer but not showing it, and a window
  dedicated to another buffer; `window-parameters`; `preserve-size`,
  `window-height`, `window-width`, `window-size`; a window-setting
  toggle removes and restores one action alist key's associations while
  the prompt stays open, and leaves `body-function` and the other
  entries;
- window-setting toggle: one per present window-setting entry, with the
  fixed Meta-digit key; user keys win; an absent entry has no toggle;
  each toggle shows the source, state, and when it applies;
  `preserve-size` applies to any chosen window; `window-height` and
  `window-width` are new windows only; `window-size` is a new frame.
  The window-settings group toggle is shown with one or more
  window-setting entries, removes all if any window-setting entry is
  active, restores all if all are removed, shows on, off, or mixed, and
  keeps the prompt open; with one window-setting entry it matches that
  entry's toggle;
- prefix command: same-window with the selected window displayable and
  not; other-window's dispatch prompt with the selected window
  ineligible, no automatic split, and the prefix's other-window request
  as the intended choice; other-tab existing and new; other-frame
  existing and new; a child frame uses the parent frame for the dispatch
  prompt; an existing target that displays the buffer shows the
  dispatch prompt with the display window as the intended choice;
  failure and selection;
- tab bar mode: selecting or making a tab enables `tab-bar-mode` when
  `tab-bar-show` is non-nil and does not when it is nil; an existing tab
  selection shows the tab bar; the frame prompt's tab step runs after
  the mode is enabled;
- option: each value of `disbuf-pivot-reuse`,
  `disbuf-pivot-same-window-conflict`, `disbuf-pivot-caller-intent-info`,
  `disbuf-pivot-exclude-conditions`, `disbuf-pivot-tab-prompt-scope`,
  `disbuf-pivot-action-select`, and
  `disbuf-pivot-other-window-prefix-select`; the default and a
  reordered `disbuf-pivot-action-functions`;
- context: batch, active minibuffer, timer, process filter, keyboard
  macro, and recursive display.

Also test C-g (quit), a nil choice (returns nil and the caller's ACTION
functions run), split failure, dead windows, an action function that
returns nil (message and `fail`) or signals an error (propagates or is
re-signaled), a `body-function` error, that selection entries are not
applied to the chosen window, that `post-command-select-window` is
honored, a window-setting toggle's all-association removal and its
local scope (later functions in Emacs's combined function list receive
the original combined action alist), and repeated choices.  Every cell
in the rules table has a test; there are no undecided cells.
