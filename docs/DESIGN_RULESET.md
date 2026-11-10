# DESIGN_RULESET

This file is the design authority for `disbuf-pivot`.  It describes the
target behavior; the source does not yet implement all of it.
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
- the tab and frame readers used by those commands.

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

Zero surprises means the user sees caller intent info when a prompt
chooses the placement, the placement is explicit, and noninteractive
calls do not prompt.  Predictable means the same intent, window state,
and options produce the same target or the same prompt; there is no
hidden cache.

## 2. Terms

Package-specific terms are defined in
`docs/DOCUMENTATION_CONVENTION.md`.  Emacs's terms are used as they
are.

## 3. Intent classes and eligibility

The package distinguishes these classes:

- **names a place** -- `window`, `slot`, `side`, `parent-frame`,
  `child-frame-parameters`, and the child-frame action.  Respect the
  caller's placement; do not prompt unless the user invoked a prefix.
- **names a tab or frame** -- a tab or frame action, `tab-name`,
  `tab-group`, or `pop-up-frames`.  Regulate the tab or frame choice:
  prompt with the tab reader or frame prompt.  An existing-target action
  preselects an existing tab or frame; a new-target action starts a new
  one and does not select an existing target.
- **names a relative placement** -- direction, below-selected,
  at-bottom.  Regulate like direction: show caller intent info, prompt
  with the window prompt, and offer a dispatch action that calls the
  caller's function.
- **names a strategy** -- same-window, reuse, other-window, new-window,
  use-some-window, use-least-recent-window.  Regulate the display by
  the rules below.
- **names a constraint** -- `reusable-frames`, `previous-window`,
  `frame-predicate`, `inhibit-switch-frame`, `window-min-width`,
  `window-min-height`, `allow-no-window`.  Honor the constraint.
- **no preference** -- use the selected window when it can display.

`display-buffer-in-child-frame` takes `parent-frame` from
`child-frame-parameters`; a top-level `parent-frame` entry is not read.
The value may name a top-level frame or a child frame.  The package's
own frame prompt offers top-level frames only.

A caller's ACTION may name several functions.  The first function is
the caller's primary intent; the later functions are the caller's
fallbacks.  Classify the first function.  If it is `Respect` or not
covered, return nil and let the whole caller list run.  If it is
`Regulate`, apply its rule.  Caller intent info names the chain:
"Caller asks for X; fallback Y."

When the rule prompts, the "use caller intent" dispatch action is a
user choice; it runs the caller's whole function list in order with the
merged alist, under a guard that prevents the package's entry from
running again.  The package does not regulate a later function; it
remains a caller fallback.  If the package cannot prompt (section 9),
it returns nil and the caller's ACTION functions run, with the later
functions as fallbacks.  If the display fails while the package can
prompt, prompt again or abort; do not return nil into the caller's
chain.  Do not reorder or deduplicate the list.  Use the first
association of an alist key, as Emacs does.  An ACTION with no function
is no preference; ACTION `t` is an other-window request (section 4).

A package prefix command is user intent, not caller intent.
`disbuf-pivot-prefix-mode` remaps the built-in prefix commands to the
package prefix commands.  The package prefix commands keep the same
override for the next command, so they take precedence over the
caller's ACTION; they make the target explicit and predictable.
Section 6 gives the target flow.

The selected window cannot display a buffer when it is a minibuffer
window, is dedicated to another buffer, is a side window, or is not
live.  `inhibit-same-window` is a caller intent shown in caller intent
info; it is not one of these conditions.

When the user chooses a window that the caller excluded with
`inhibit-same-window`, the user's choice wins.  Bind that entry to nil
for the display call; caller intent info says the caller asked for a
non-selected window.

## 4. Rules

| Case | Behavior | Caller intent info |
|---|---|---|
| Same-window, selected window can display | Use the selected window; no prompt | None |
| Same-window, selected window cannot display | Prompt with the window prompt; offer split actions | "Caller asks for same window; selected window cannot display" |
| Same-window plus `inhibit-same-window` | Report the conflict; `disbuf-pivot-same-window-conflict` chooses same window or the window prompt | Conflict message |
| No preference, selected window can display | Use the selected window; no prompt | None |
| No preference, selected window cannot display | Prompt with the window prompt; offer split actions | "Selected window cannot display the buffer" |
| A window displays the buffer | Reuse the preferred window; `disbuf-pivot-reuse` can ask instead | "Reuse; window(s) X display the buffer" |
| Reuse intent, no window displays the buffer | Prompt with the window prompt; offer split actions | "Reuse; no window displays the buffer" |
| Reuse intent, several windows display the buffer | `disbuf-pivot-reuse` chooses auto or ask; ask marks the reuse windows | "Reuse; windows X, Y display the buffer" |
| Use some window | Prompt with the window prompt; show caller intent info; let the user choose; offer split actions | "Caller asks for some window" |
| Use least recent window | Prompt with the window prompt; show caller intent info; let the user choose; offer split actions | "Caller asks for a recently unused window" |
| Caller sets `inhibit-same-window` | Show caller intent info; prompt with the window prompt; the user may choose an existing window or a dispatch action, including the selected window | "Caller asks for a non-selected window" |
| Other-window | Prompt with the window prompt; exclude the selected window; offer split actions | "Caller asks for other window" |
| New-window | Prompt; offer split and new-frame actions; do not offer existing windows | "Caller asks for new window" |
| Direction | Prompt with the window prompt; show caller intent info; offer a dispatch action that applies the direction; leave side windows as-is | "Caller asks for direction X" |
| Below-selected / at-bottom | Prompt with the window prompt; show caller intent info; offer a dispatch action that calls the caller's function; leave side windows as-is | "Caller asks for a window below the selected window" or "at the bottom of the frame" |
| Previous window | Prompt with the window prompt; show the named `previous-window` as the preferred candidate, or mark the windows that previously showed the buffer; use `disbuf-pivot-reuse` when no previous window is usable | "Caller asks for previous window X" or "Caller asks for a window that previously showed the buffer" |
| Tab or frame action | The other-frame prefix prompts frame, then tab when needed, then window.  A caller's tab or frame action prompts with the tab reader or frame prompt.  An existing-target action preselects an existing tab or frame; a new-target action starts a new one and does not select an existing tab or frame with the same name | "Caller asks for existing tab/frame X" or "Caller asks for a new tab/frame" |
| Placed `window`, `slot`, `parent-frame`, `child-frame-parameters` | Respect the caller's placement; no prompt | Optional |
| Side window | Leave the caller's side placement as-is; no prompt | Optional |
| ACTION `t` | Treat as an other-window request; exclude the selected window; prompt | "Caller asks for other window" |
| Caller ACTION with several functions | Classify the first function; later functions are the caller's fallbacks.  The "use caller intent" action runs the whole list in order when the user chooses it | "Caller asks for X; fallback Y" |
| `allow-no-window` and the user chooses no display | Call `display-buffer-no-window`; return `fail` | "No window requested" |
| Excluded buffer | Return nil; the caller's action or the remaining display rules run; no prompt | None |
| Anything not covered | Return nil; the caller's action or the remaining display rules run | Optional |
| `switch-to-buffer` | Default; it obeys the rules only with `switch-to-buffer-obey-display-actions` | None |

## 5. Options and defaults

- `disbuf-pivot-reuse` -- `auto` (default) or `ask`.  It applies when
  a window already displays the buffer, and to the previous-buffer
  candidates of `display-buffer-in-previous-window`.
- `disbuf-pivot-same-window-conflict` -- `ask` (default) or
  `same-window`.  It applies when the caller asks for the same window
  and sets `inhibit-same-window`.
- `disbuf-pivot-action-functions` -- the action functions the entry
  tries, in order.  The default is `display-buffer-reuse-window`,
  `display-buffer-same-window`, and `dp-action-choose-window`; it does
  not include an automatic split.
- `disbuf-pivot-caller-intent-info` -- non-nil (default) shows one
  brief line for prompted placements.  Silent selected-window defaults
  show no info.  Nil hides the line for prompts.
- `disbuf-pivot-exclude-conditions` -- nil (default) or a list of
  `buffer-match-p` conditions.  A matching buffer is not regulated:
  the entry returns nil and the caller's action or the remaining
  display rules apply.  A condition can match the buffer name (a
  regexp), a derived major mode (`(derived-mode . MODE)`), or a
  predicate (`(predicate . FN)`).
- `disbuf-pivot-mode-line-help` -- nil (default) hides the dispatch
  hint in the mode line; non-nil shows it.  It does not affect the
  echo-area dispatch hint or `ace-window-display-mode` labels.
- `disbuf-pivot-action-select` -- `auto` (default), `t`, or `nil`.
  It controls selection after an action-mode prompt.
- `disbuf-pivot-other-window-prefix-select` -- `auto` (default), `t`,
  or `nil`.  It controls selection after the other-window prefix.

C-g always aborts; there is no option for it.

Automatic split is not part of the core.  Split actions are user
choices in the prompt.  `disbuf-pivot-window-utility-split-p` and its
options are not consulted by the core behavior.

Frame preview is not part of the first implementation.  The tab preview
with consult remains optional.

Windows that cannot display are labelled and marked as ineligible.
Choosing one repeats the prompt.

## 6. Interaction rules

- The window prompt calls `aw-select` to label and read a window.
  `disbuf-pivot-mode-line-help` controls only the mode-line copy of the
  dispatch hint; nil by default.  The dispatch hint is not the dispatch
  action list; `?` shows the dispatch action list in the echo area.
  The echo area shows the dispatch hint, appended to caller intent info
  when that line is shown, independent of the mode-line option.  Show
  it as its own message when caller intent info is not shown.  Bind
  `aw-minibuffer-flag` to nil around `aw-select` so ace-window does not
  echo the mode-line string.  Show caller intent info before the window
  prompt.  The echo area also holds the repeat message.
- The dispatch prompt is the one-window echo-area prompt; it reads one
  key and labels no windows.
- The dispatch action list groups the actions:
  - **Split**: the split actions from `aw-dispatch-alist`, with their
    keys and descriptions.
  - **Caller intent**: "Use caller intent" and any caller action the
    rule offers, named by its user-facing action, not by the raw
    function.
  - **Other**: a new frame for a new-window intent; leave undisplayed
    only with `allow-no-window`.
  One fallback line follows: "Any other key uses this window," or "Any
  other key cancels" when the selected window is ignored.
- The list is generated from `aw-dispatch-alist` and the package's
  actions; do not hardcode keys.  A package key is offered only when it
  does not collide with `aw-dispatch-alist`.
- The window prompt shows the dispatch action list on demand: the
  caller intent line carries the dispatch hint, and `?` shows the list.
  The one-window dispatch prompt shows the grouped list with its one-key
  read.
- Caller intent info is one line.  Detailed information goes in the
  dispatch action list.
- The package checks `disbuf-pivot-exclude-conditions` in its entry
  condition before recording the ACTION.  A matching buffer returns
  nil; no prompt runs, and the caller's ACTION and the remaining display
  rules apply.  `display-buffer-overriding-action` and earlier
  `display-buffer-alist` entries still take precedence.
- C-g aborts the display; it does not run the caller's fallbacks.  The
  "use caller intent" action is the explicit way to run the chain.
- The prompt offers a leave-undisplayed dispatch action only when
  `allow-no-window` is non-nil.
- A split action ends a repeat.  If the split action fails, show the
  error and prompt again.
- Selection follows the caller.  The package does not select the
  chosen window unless the selection option says so.
- Frame focus and raising use the standard action functions and honor
  `inhibit-switch-frame`.
- For the other-frame prefix, the order is frame, then tab when needed,
  then window.  A new frame uses its selected window.  Skip the tab
  prompt for a new frame, and for a frame with one tab unless
  `tab-bar-mode` is active.
- An existing-target action preselects an existing tab or frame; a
  new-target action starts a new one and must not select an existing
  tab or frame with the same name.  The prompt string states the
  caller's intention; the later window prompt shows it in caller intent
  info.
- Reuse caller intent info names the qualifying windows.  Same-window
  and no-preference info is optional.
- The same-window conflict message states that the caller's requests
  conflict, then applies `disbuf-pivot-same-window-conflict`.
- Direction uses `display-buffer-in-direction` for the "use caller
  intent" dispatch action.  Below-selected and at-bottom use their own
  functions for that action.  Side windows are left as-is.
- The four package prefix commands are remapped: same-window,
  other-window, other-tab, and other-frame.

## 7. Action function checklist

`Regulate` means the package handles the display under its own rules:
it shows caller intent info, prompts when needed, lets the user choose
an existing window or a dispatch action, and displays the buffer in the
chosen window.  Calling an Emacs action function is the display
primitive, not a delegation of the regulation.

`Respect` means the package returns nil without displaying; the
caller's action runs.

The table describes a caller's ACTION that names the function.  A
package prefix command or a user choice in a prompt is separate; the
package may call the same function after that choice.

The table applies when the function is the first function in the
caller's ACTION.  A later function in the same ACTION is a caller
fallback; section 3 gives the rule for a list of functions.

| Action function | Treatment | Relevant alists |
|---|---|---|
| `display-buffer-same-window` | Regulate.  If the user chooses the selected window despite `inhibit-same-window`, bind that entry to nil for this call. | `inhibit-same-window` |
| `display-buffer-reuse-window` | Regulate.  If the user chooses a window the caller excluded, bind `inhibit-same-window` to nil for this call. | `inhibit-same-window`, `reusable-frames`, `inhibit-switch-frame`, `reuse-indirect` |
| `display-buffer-reuse-mode-window` | Regulate as reuse with `mode`. | `mode`, `inhibit-same-window`, `reusable-frames`, `inhibit-switch-frame` |
| `display-buffer-pop-up-window` | Regulate for a split action. | `inhibit-switch-frame`; shared window alists |
| `display-buffer-in-previous-window` | Regulate.  Show the `previous-window` entry as the preferred candidate; when it is not usable, mark the windows that previously showed the buffer. | `previous-window`, `inhibit-same-window`, `reusable-frames` |
| `display-buffer-use-some-window` | Regulate: show caller intent info, prompt with the window prompt, and let the user choose.  Do not let the function choose silently. | `some-window`, `lru-frames`, `lru-time`, `window-min-width`, `window-min-height`, `inhibit-same-window`, `inhibit-switch-frame` |
| `display-buffer-use-least-recent-window` | Regulate like `display-buffer-use-some-window`. | `reusable-frames`, `inhibit-switch-frame`, `lru-frames`, `lru-time`, `window-min-width`, `window-min-height`; `inhibit-same-window` is forced to t internally |
| `display-buffer-in-direction` | Regulate for the "use caller intent" direction action. | `direction`, `window` |
| `display-buffer-below-selected` | Regulate for the below direction.  `window-min-height` is an eligibility constraint. | `window-min-height` |
| `display-buffer-at-bottom` | Regulate for the at-bottom direction. | None specific |
| `display-buffer-full-frame` | Respect.  Delegated to `display-buffer-reuse-window`, `display-buffer-same-window`, `display-buffer-pop-up-window`, and `display-buffer-use-some-window` in that order. | None specific |
| `display-buffer-pop-up-frame` | Regulate for a new frame.  Ask for a new frame name; do not offer existing frames.  Use `pop-up-frame-parameters`; the new frame is top-level unless that entry sets `parent-frame`. | `pop-up-frame-parameters`, `inhibit-switch-frame`; `pop-up-frames` selects the frame strategy but is not read by this function |
| `display-buffer-use-some-frame` | Regulate for an existing frame; `frame-predicate` filters the candidates. | `frame-predicate`, `inhibit-same-window`, `inhibit-switch-frame` |
| `display-buffer-in-child-frame` | Respect. | `child-frame-parameters` (including a `parent-frame` entry naming a top-level or child frame), `inhibit-switch-frame` |
| `display-buffer-in-tab` | Regulate; preselect an existing or reusable tab; a new tab starts without an existing-tab preselect. | `reusable-frames` (nil differs), `ignore-current-tab`, `tab-name`, `tab-group` |
| `display-buffer-in-new-tab` | Regulate; ask for a new tab name; do not select an existing tab with the same name. | `tab-name`, `tab-group` |
| `display-buffer-in-side-window` | Respect; side as-is. | `side`, `slot` |
| `display-buffer-in-atom-window` | Respect. | `side`, `window` |
| `display-buffer-no-window` | Regulate: leave undisplayed; only with `allow-no-window`. | `allow-no-window` |

## 8. Action alist checklist

The package passes the merged alist to the function it calls.  It does
not drop an entry except `inhibit-same-window` when the user overrides
it.  Entries used during the prompt are interpreted as follows.

| Entry | Treatment |
|---|---|
| `inhibit-same-window` | Show caller intent info; call the window prompt; the user may choose an existing window or a dispatch action.  Keep the selected window a candidate; bind this entry to nil for the display call if the user chooses it. |
| `previous-window` | Show the named window as the preferred candidate when it is displayable; do not force it.  Without a usable entry, mark the windows that previously showed the buffer. |
| `mode` | Pass to `display-buffer-reuse-mode-window` when reuse is regulated with a mode. |
| `frame-predicate` | Frame candidates; honor. |
| `reusable-frames` | Reuse and tab scope; honor.  The tab meaning of nil differs. |
| `inhibit-switch-frame` | Frame raising and focus; honor. |
| `window-parameters`, `dedicated`, `preserve-size`, `window-height`, `window-width`, `window-size` | Apply to the chosen window through the standard display path. |
| `window-min-width`, `window-min-height` | Eligibility constraints; honor when choosing a window. |
| `some-window`, `lru-frames`, `lru-time` | Pass to `display-buffer-use-some-window` or `display-buffer-use-least-recent-window` when the package calls it; otherwise leave in the alist. |
| `bump-use-time` | Bump the chosen window's use time; handled by `window--display-buffer`. |
| `pop-up-frame-parameters` | New-frame parameters; honor. |
| `pop-up-frames` | Selects the frame strategy; `display-buffer-pop-up-frame` does not read it.  The reuse functions use it as the frame scope when `reusable-frames` has no entry. |
| `child-frame-parameters` (including a `parent-frame` entry naming a top-level or child frame) | Child-frame placement; respect. |
| `side`, `slot` | Side placement; leave as-is. |
| `direction`, `window` | Direction action; honor. |
| `allow-no-window` | Allow the leave-undisplayed outcome. |
| `body-function` | Apply after the buffer is displayed. |
| `post-command-select-window` | Honor; the selection option defaults to `auto`. |
| `category` | Pass through; use it in caller intent info when present. |
| `tab-name`, `tab-group`, `ignore-current-tab` | Tab flow; honor. |
| `reuse-indirect` | Pass to `display-buffer-reuse-window`. |

## 9. Contexts

The package cannot prompt in the batch, active-minibuffer, timer,
process-filter, keyboard-macro, and recursive-display contexts below.
In them none of the window prompt, the dispatch prompt, the tab reader,
or the frame prompt runs; the action returns nil.

- Batch: return nil.  Do not prompt.
- Active minibuffer: return nil.  Do not prompt.
- Timer, process filter, or keyboard macro: return nil.  Do not prompt.
- Daemon or text terminal: the same prompt rules apply; the window
  prompt may still work.
- Recursive display during tab or frame creation, or during a preview:
  return nil for the nested call.
- Multiple `display-buffer` calls in one command: no cache.
- Failure after the choice: if the window is dead, repeat; if the frame
  or tab is gone, prompt again; if the display function errors, report
  it and abort.  Do not return nil into the caller's chain while a
  prompt can run.
- A nil return is reserved for the cannot-prompt contexts and the
  Respect or not-covered cases; the caller's ACTION functions and the
  remaining display rules run after it.

## 10. Implementation tasks

1. Add the options in section 5 with the stated defaults.
2. Change the default action list: replace `dp-action-split-or-ask`
   with `dp-action-choose-window`; split actions are prompt choices
   only.
3. Classify the first function in the caller's ACTION; later functions
   are the caller's fallbacks.  Respect the classes in section 3; return
   nil for anything the package does not regulate.  The "use caller
   intent" action runs the caller's whole function list in order when
   the user chooses it.  A failed interactive display prompts again or
   aborts; it does not return nil into the caller's chain.
4. Regulate same-window, reuse, other-window, new-window,
   use-some-window, use-least-recent-window, direction, below-selected,
   at-bottom, previous window, and the tab and frame choices.  Use the
   tab reader and frame prompt; an existing-target action preselects an
   existing tab or frame, and a new-target action starts a new one and
   does not select an existing target.  Keep the tab and frame flows of
   the package prefix commands.  Use the action functions in section 7
   as the display primitives.
5. Handle `inhibit-same-window`: show caller intent info, call the
   window prompt, keep the selected window, and bind the entry to nil
   when the user chooses it.
6. Put caller intent info and the dispatch hint in the echo area.  The
   mode-line copy is optional (`disbuf-pivot-mode-line-help`).  Show
   one brief line for prompted placements.
7. Make C-g abort.  Remove any option that changes C-g behavior.
8. Default selection to `auto`; honor `post-command-select-window`;
   keep `t` and `nil` as forcing options.
9. Label every window; mark windows that cannot display; choose again
   when one is chosen.
10. Add the context guard from section 9.
11. Add tests for every rule in section 4, every action function in
    section 7, every action alist entry in section 8, and every context
    in section 9.
12. Update `README.md` and `CHANGELOG.md` after the behavior is
    implemented.

## 11. Test matrix

Every rule needs a Buttercup test.  Combine:

- caller intent: same-window, no preference, reuse with a target, reuse
  without a target, other-window, new-window, use some window, use least
  recent window, direction, below-selected, at-bottom, previous window,
  existing tab, new tab, existing frame, new frame, placed, side, ACTION
  `t`, `allow-no-window`, `switch-to-buffer`;
- caller ACTION: one function, several functions, all-Regulate,
  all-Respect, mixed, duplicate, empty, and an inapplicable first
  function;
- tab and frame readers: an existing-target action preselects an
  existing tab or frame; a new-target action starts a new one and does
  not select an existing one; the prompt string states the caller's
  intention;
- window state: selected window eligible, dedicated, side, minibuffer,
  and dead; window already displaying the buffer or not;
- target state: existing, new, none;
- caller constraint: none, `inhibit-same-window`, `reusable-frames`,
  `previous-window`, `frame-predicate`, `allow-no-window`;
- option: each value of `disbuf-pivot-reuse`,
  `disbuf-pivot-same-window-conflict`, `disbuf-pivot-caller-intent-info`,
  `disbuf-pivot-action-select`, and
  `disbuf-pivot-other-window-prefix-select`;
- context: batch, active minibuffer, timer, process filter, keyboard
  macro, and recursive display.

Also test C-g, split failure, dead windows, display errors (prompt again
or abort, never the caller's fallbacks), and repeated choices.  Every
cell in the rules table has a test; there are no undecided cells.
