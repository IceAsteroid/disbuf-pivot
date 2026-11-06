# DESIGN_RULESET

This file is the design authority for `disbuf-pivot`.  It describes the
target behavior; the source does not yet implement all of it.
`TERM_AND_CONVENTION.md` is the authority for terms, prose, and commit
messages.  Define a term there, not here.

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

Package-specific terms are defined in `TERM_AND_CONVENTION.md`.
Emacs's terms are used as they are.

## 3. Intent classes and eligibility

The package distinguishes five classes:

- **names a place** -- `window`, `slot`, `side`, `parent-frame`,
  `child-frame-parameters`, `tab-name`, `tab-group`, and the tab and
  frame action functions.  Respect the caller's placement; do not
  prompt unless the user invoked a prefix.
- **names a strategy** -- same-window, reuse, other-window, new-window.
  Regulate the display by the rules below.
- **names a constraint** -- `reusable-frames`, `previous-window`,
  `frame-predicate`, `allow-no-window`.  Honor the constraint.
- **referential** -- `inhibit-same-window`.  Show it as caller intent
  info; it does not decide the window or remove the selected window
  from the candidates.
- **no preference** -- use the selected window when it can display.

A package prefix command is user intent, not caller intent.
`disbuf-pivot-prefix-mode` remaps the built-in prefix commands to the
package prefix commands.  The package prefix commands keep the same
override for the next command, so they take precedence over the
caller's ACTION; they make the target explicit and predictable.
Section 6 gives the target flow.

The selected window cannot display a buffer when it is a minibuffer
window, is dedicated to another buffer, is a side window, or is not
live.  `inhibit-same-window` is referential and is not one of these
conditions.

When the user chooses a window that a referential caller intent
excluded, the user's choice wins.  Bind the relevant alist entry to nil
for the display call; caller intent info says what was excluded.

## 4. Rules

| Case | Behavior | Caller intent info |
|---|---|---|
| Same-window, selected window can display | Use the selected window; no prompt | None |
| Same-window, selected window cannot display | Prompt with `ace-window`; offer split actions | "Caller asks for same window; selected window cannot display" |
| Same-window plus `inhibit-same-window` | Report the conflict; `disbuf-pivot-same-window-conflict` chooses same window or `ace-window` | Conflict message |
| No preference, selected window can display | Use the selected window; no prompt | None |
| No preference, selected window cannot display | Prompt with `ace-window`; offer split actions | "Selected window cannot display the buffer" |
| A window displays the buffer | Reuse the preferred window; `disbuf-pivot-reuse` can ask instead | "Reuse; window(s) X display the buffer" |
| Reuse intent, no window displays the buffer | Prompt with `ace-window`; offer split actions | "Reuse; no window displays the buffer" |
| Reuse intent, several windows display the buffer | `disbuf-pivot-reuse` chooses auto or ask; ask marks the reuse windows | "Reuse; windows X, Y display the buffer" |
| Caller sets `inhibit-same-window` | Show caller intent info; prompt with `ace-window`; the selected window remains a candidate | "Caller asks for a non-selected window" |
| Other-window | Prompt with `ace-window`; exclude the selected window; offer split actions | "Caller asks for other window" |
| New-window | Prompt; offer split and new-frame actions; do not offer existing windows | "Caller asks for new window" |
| Direction | Prompt with `ace-window`; show caller intent info; offer a dispatch action that applies the direction; leave side windows as-is | "Caller asks for direction X" |
| Tab or frame | A prefix prompts frame, then tab when needed, then window.  A caller's explicit tab or frame action is left to the caller with caller intent info | "Caller asks for other tab/frame" |
| Placed `window`, `slot`, `parent-frame`, `child-frame-parameters` | Respect the caller's placement; no prompt | Optional |
| Side window | Leave the caller's side placement as-is; no prompt | Optional |
| ACTION `t` | Treat as an other-window request; exclude the selected window; prompt | "Caller asks for other window" |
| `allow-no-window` and the user chooses no display | Call `display-buffer-no-window`; return `fail` | "No window requested" |
| Anything not covered | Return nil; the caller's action or the remaining display rules run | Optional |
| `switch-to-buffer` | Default; it obeys the rules only with `switch-to-buffer-obey-display-actions` | None |

## 5. Options and defaults

- `disbuf-pivot-reuse` -- `auto` (default) or `ask`.  It applies when
  a window already displays the buffer.
- `disbuf-pivot-same-window-conflict` -- `ask` (default) or
  `same-window`.  It applies when the caller asks for the same window
  and sets `inhibit-same-window`.
- `disbuf-pivot-caller-intent-info` -- non-nil (default) shows one
  brief line for prompted placements.  Silent selected-window defaults
  show no info.  Nil hides the line for prompts.
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

- The mode line holds the ace prompt.  The echo area holds caller
  intent info.
- Caller intent info is one line.  Detailed information goes in the
  dispatch help.
- C-g aborts the prompt.
- The prompt offers a leave-undisplayed dispatch action only when
  `allow-no-window` is non-nil.
- A split action ends a repeat.  If the split action fails, show the
  error and prompt again.
- Selection follows the caller.  The package does not select the
  chosen window unless the selection option says so.
- Frame focus and raising use the standard action functions and honor
  `inhibit-switch-frame`.
- The tab and frame order is frame, then tab when needed, then window.
  A new frame uses its selected window.  Skip the tab prompt for a new
  frame, and for a frame with one tab unless `tab-bar-mode` is active.
- Reuse caller intent info names the qualifying windows.  Same-window
  and no-preference info is optional.
- The same-window conflict message states that the caller's requests
  conflict, then applies `disbuf-pivot-same-window-conflict`.
- Direction uses `display-buffer-in-direction` for the "use caller
  intent" dispatch action.  Side windows are left as-is.
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

| Action function | Treatment |
|---|---|
| `display-buffer-same-window` | Regulate.  If the user chooses the selected window despite `inhibit-same-window`, bind that entry to nil for this call. |
| `display-buffer-reuse-window` | Regulate.  If the user chooses a window the caller excluded, bind `inhibit-same-window` to nil for this call. |
| `display-buffer-reuse-mode-window` | Regulate as reuse with `mode`. |
| `display-buffer-pop-up-window` | Regulate for a split action. |
| `display-buffer-in-previous-window` | Respect.  The `previous-window` entry is shown as a preference when the package prompts. |
| `display-buffer-use-some-window` | Regulate: show caller intent info, prompt with `ace-window`, and let the user choose.  Do not let the function choose silently. |
| `display-buffer-use-least-recent-window` | Regulate like `display-buffer-use-some-window`. |
| `display-buffer-in-direction` | Regulate for the "use caller intent" direction action. |
| `display-buffer-below-selected` | Respect. |
| `display-buffer-at-bottom` | Respect. |
| `display-buffer-full-frame` | Respect. |
| `display-buffer-pop-up-frame` | Respect. |
| `display-buffer-use-some-frame` | Respect. |
| `display-buffer-in-child-frame` | Respect. |
| `display-buffer-in-tab` | Respect. |
| `display-buffer-in-new-tab` | Respect. |
| `display-buffer-in-side-window` | Respect; side as-is. |
| `display-buffer-in-atom-window` | Respect. |
| `display-buffer-no-window` | Regulate: leave undisplayed; only with `allow-no-window`. |

## 8. Action alist checklist

The package passes the merged alist to the function it calls.  It does
not drop an entry except `inhibit-same-window` when the user overrides
it.  Entries used during the prompt are interpreted as follows.

| Entry | Treatment |
|---|---|
| `inhibit-same-window` | Referential.  Show caller intent info; keep the selected window a candidate; bind this entry to nil for the display call if the user chooses it. |
| `previous-window` | Honor as a preference.  When the caller's action runs, it receives the entry.  When the package prompts for another intent, show the named window as preferred; do not force it. |
| `mode` | Pass to `display-buffer-reuse-mode-window` when reuse is regulated with a mode. |
| `frame-predicate` | Frame candidates; honor. |
| `reusable-frames` | Reuse and tab scope; honor.  The tab meaning of nil differs. |
| `inhibit-switch-frame` | Frame raising and focus; honor. |
| `window-parameters`, `dedicated`, `preserve-size`, `window-height`, `window-width`, `window-size` | Apply to the chosen window through the standard display path. |
| `window-min-width`, `window-min-height` | Eligibility constraints; honor when choosing a window. |
| `some-window`, `lru-frames`, `lru-time`, `bump-use-time` | Pass to `display-buffer-use-some-window` or `display-buffer-use-least-recent-window` when the package calls it; otherwise leave in the alist. |
| `pop-up-frame-parameters`, `pop-up-frames` | New-frame handling; honor. |
| `parent-frame`, `child-frame-parameters` | Child-frame placement; respect. |
| `side`, `slot` | Side placement; leave as-is. |
| `direction`, `window` | Direction action; honor. |
| `allow-no-window` | Allow the leave-undisplayed outcome. |
| `body-function` | Apply after the buffer is displayed. |
| `post-command-select-window` | Honor; the selection option defaults to `auto`. |
| `category` | Pass through; use it in caller intent info when present. |
| `tab-name`, `tab-group`, `ignore-current-tab` | Tab flow; honor. |
| `reuse-indirect` | Pass to `display-buffer-reuse-window`. |

## 9. Contexts

- Batch: return nil.  Do not prompt.
- Active minibuffer: return nil.  Do not prompt.
- Timer, process filter, or keyboard macro: return nil.  Do not prompt.
- Daemon or text terminal: the same prompt rules apply; `ace-window`
  may still work.
- Recursive display during tab or frame creation, or during a preview:
  return nil for the nested call.
- Multiple `display-buffer` calls in one command: no cache.
- Failure after the choice: if the window is dead, repeat; if the frame
  or tab is gone, prompt again; if the display function errors, report
  it and return nil.

## 10. Implementation tasks

1. Add the options in section 5 with the stated defaults.
2. Change the default action list: remove `dp-action-split-or-ask`;
   split actions are prompt choices only.
3. Classify the caller's intent before displaying.  Respect the
   classes in section 3; return nil for anything the package does not
   regulate.
4. Regulate same-window, reuse, other-window, new-window, and
   direction.  Keep the tab and frame flows of the package prefix
   commands; respect a caller's explicit tab or frame action.  Use the
   action functions in section 7 as the display primitives.
5. Implement referential `inhibit-same-window`: show caller intent
   info, keep the selected window, and bind the entry to nil when the
   user chooses it.
6. Put caller intent info in the echo area.  Keep the mode line as the
   ace prompt.  Show one brief line for prompted placements.
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
  without a target, other-window, new-window, direction, tab, frame,
  placed, side, ACTION `t`, `allow-no-window`, `switch-to-buffer`;
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

Also test C-g, split failure, dead windows, and repeated choices.  Every
cell in the rules table has a test; there are no undecided cells.
