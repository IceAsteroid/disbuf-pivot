# DESIGN_RULESET

This file is the design authority for `disbuf-pivot`.  It describes the
target behavior; the source does not yet implement all of it.
`TERM_AND_CONVENTION.md` remains the authority for terms, prose, and
commit messages.  Define a term there, not here.

## 1. Goal and scope

`disbuf-pivot` replaces an implicit `display-buffer` choice with an
explicit one.  It aims for predictable display management, zero
surprises, and an explicit choice for the user.

`disbuf-pivot` is a policy layer.  It may call a standard Emacs action
function to perform the final display, but the target choice and the
prompt remain the package's.

Full coverage means:

- every `display-buffer` call that reaches the package's
  `display-buffer-alist` entry;
- the four prefix commands;
- the tab and frame readers used by those commands.

Full coverage does not mean every buffer-switching command.  It does not
include `switch-to-buffer`, completion previews, timers, process
filters, or calls handled by `display-buffer-overriding-action` or an
earlier `display-buffer-alist` entry.  `switch-to-buffer` remains
default; it obeys the display rules only when
`switch-to-buffer-obey-display-actions` is non-nil.

`column-popup` owns the buffers it declares; `disbuf-pivot` handles the
remaining buffers.  The intended entry order is `column-popup` first,
`disbuf-pivot` second.  Both packages cons their entry at the front of
`display-buffer-alist` when their mode is enabled, so the user's
enabling order sets the precedence: enable `disbuf-pivot` first, then
`column-popup`.  The package does not force an order.

Zero surprises means:

- the user sees the caller intent info when a prompt chooses the
  placement;
- the resulting placement is explicit and explained;
- noninteractive calls do not prompt.

Predictable means the same intent, window state, and options produce the
same target or the same prompt.  There is no hidden cache.

## 2. Terms

The terms used here are defined in `TERM_AND_CONVENTION.md`.  The
package terms are **chosen window**, **caller intent info**,
**referential**, and **cannot display**.  Emacs's terms, such as the
selected window, are used as they are.  The term file is the authority.

## 3. Intent classes

The package distinguishes five classes:

- **names a place** -- `window`, `direction`, `side`, `slot`,
  `parent-frame`, `child-frame-parameters`, `tab-name`, `tab-group`,
  and the tab and frame action functions.  Respect the caller's
  placement; do not prompt unless the user invoked a prefix.
- **names a strategy** -- same-window, reuse, other-window, new-window.
  Resolve by the behavior table; prompt when the strategy leaves the
  target open.
- **names a constraint** -- `reusable-frames`, `previous-window`,
  `frame-predicate`, `allow-no-window`.  Respect the constraint; show
  it as caller intent info.
- **referential** -- `inhibit-same-window`.  Show it as caller intent
  info; do not use it to decide the window or remove the selected
  window from the candidates.
- **no preference** -- use the selected window when it can display.

Separate from these classes, the selected window cannot display a
buffer when it is a minibuffer window, is dedicated to another buffer,
is a side window if the side policy says so, or is not live.
`inhibit-same-window` is referential and is not one of these
conditions.

A prefix command is user intent, not caller intent.  A prefix may prompt
for its target even when the caller named a place.

## 4. Behavior table

`Open` marks a cell that needs a maintainer decision.  `Open` means not
yet approved, not undefined.

| Case | Default behavior | Prompt | Caller intent info | Status |
|---|---|---|---|---|
| Same-window, selected window can display | Display in the selected window | None | Optional; default off recommended | Behavior settled; info option open |
| Same-window, selected window cannot display | `ace-window` | Eligible windows and split actions | "Caller asks for same window; selected window cannot display" | Settled |
| Same-window plus `inhibit-same-window` | Report the conflict | Option: same window or `ace-window` | Conflict message | Settled; option default open |
| No preference, selected window can display | Display in the selected window | None | Optional; default off recommended | Settled |
| No preference, selected window cannot display | `ace-window` | Eligible windows and split actions | "Selected window cannot display the buffer" | Settled |
| A window displays the buffer | Reuse option decides; recommended auto-reuse the preferred window | Ask only if the reuse option says so | "Reuse; window(s) X display the buffer" | Option default open |
| Reuse intent, no window displays the buffer | `ace-window` | Eligible windows and split actions | "Reuse; no window displays the buffer" | Settled |
| Reuse intent, several windows display the buffer | Reuse option | Auto, or ask with reuse windows marked | "Reuse; windows X, Y display the buffer" | Option details open |
| Caller sets `inhibit-same-window` | Show caller intent info; `ace-window` | Eligible windows and split actions; the selected window remains a candidate | "Caller asks for a non-selected window" | Settled (referential) |
| Other-window | `ace-window` | Eligible windows and split actions; whether the selected window is a candidate is open | "Caller asks for other window" | Core settled; selected candidate open |
| New-window | Prompt | Split and new-frame actions; existing windows are not offered by default | "Caller asks for new window" | Open |
| Direction | Respect the caller's action | A prefix or option can prompt with a "use caller intent" dispatch action | "Caller asks for direction X" | Direction info settled; mechanics open |
| Tab or frame | A prefix prompts frame, then tab when needed, then window; a caller's explicit action is respected or shown | Tab or frame list, then the window prompt | "Caller asks for other tab/frame" | Core settled; details open |
| Placed `window`, `slot`, `parent-frame`, `child-frame-parameters` | Open: respect the caller's action or prompt | Open | Optional | Open |
| Side window | As-is | None | Optional | Settled |
| ACTION `t` | Recommended: treat as an other-window request | Whether the selected window is a candidate is open | "Caller asks for other window" | Recommended; open |
| `switch-to-buffer` | Default | None | None | Settled |

## 5. Policy choices

These are the choices that need the maintainer's approval.  The rest of
the behavior is derived from the Emacs action-function and action-alist
tables.

1. **ACTION `t`.**  Treat it as a constraint or as caller intent info.
   Open.  (`inhibit-same-window` is referential by the term
   definition.)
2. **Reuse default.**  Auto-reuse or ask.  Recommended: auto-reuse;
   ask as an option.
3. **Split.**  Prompt-first or automatic.  Recommended: prompt-first;
   automatic split as an option, off by default.
4. **Selection.**  Let the caller decide or always select the chosen
   window.  Recommended: caller decides; an option to force selection.
5. **Cancellation.**  C-g aborts, or C-g is configurable.  Recommended:
   C-g always aborts.  Use separate dispatch actions for "use selected
   window" and "leave undisplayed."
6. **Same-window caller intent info.**  Default on or off.
   Recommended: off; it is noise when no prompt appears.
7. **Sole-window dispatch list.**  A curated display list or the full
   `aw-dispatch-alist`.  Recommended: curated; full list as an option.
8. **Windows that cannot display.**  Exclude them from the labels, or
   label them and mark them as ineligible.  Recommended: mark them.
9. **Frame and tab details.**  Candidates, prompt conditions, focus,
   and preview restoration.  See section 10.

## 6. Interaction rules

This section assumes the recommended defaults in section 5.  The open
choices remain open until the maintainer approves them.

- The mode line holds the ace prompt.  The echo area holds caller
  intent info.
- Caller intent info is one line.  Detailed information can go in the
  dispatch help; the feature must not depend on `?` being bound.
- C-g aborts by default.  "Use selected window" and "leave undisplayed"
  are separate dispatch actions.
- "Leave undisplayed" calls `display-buffer-no-window`, and only when
  `allow-no-window` is non-nil.  Otherwise the buffer can still be
  displayed by the caller's rules; report that.
- "Run the caller's default intent" returns nil from the package's
  action function, so the caller's ACTION, the base action, and the
  fallback run.
- Selection follows the caller by default.  An option can force
  selection or force no selection.
- A repeat is allowed.  C-g or a split action ends it.  If the split
  action fails, show the error and repeat.
- Frame focus and raising use the standard action functions and honor
  `inhibit-switch-frame`.
- The tab and frame order is frame, then tab when needed, then window.
  A new frame uses its selected window.  Skip the tab prompt for a new
  frame, and for a frame with one tab unless `tab-bar-mode` is active.
- Reuse caller intent info names the qualifying windows.  Same-window
  and no-preference info is optional.
- The same-window conflict message states that the caller's requests
  conflict, then applies the selected option.
- Direction uses `display-buffer-in-direction` for the "use caller
  intent" action.  Side windows are left as-is.
- `inhibit-same-window` is referential: show it as caller intent info
  and keep the selected window a candidate.  If the user chooses a
  window the caller excluded, bind the relevant alist entry to nil for
  the display call; otherwise the standard action function refuses the
  choice.  When the package prompts, the user's explicit choice wins
  over a referential caller intent.
- The four prefix commands are remapped: same-window, other-window,
  other-tab, and other-frame.

## 7. Action function checklist

`Regulate` means the package handles the display under its own rules:
it may show caller intent info, prompt with `ace-window`, let the user
choose an existing window or a dispatch action, and display the buffer
in the chosen window.  Calling a standard Emacs action function is the
display mechanism, not a delegation of the package's regulation.
`Respect` means the package returns nil without displaying, so
`display-buffer` continues to the caller's action.  The package does
not create, modify, or kill the buffer; it returns a window, nil, or
`fail` through `display-buffer-no-window`.

| Action function | Treatment |
|---|---|
| `display-buffer-same-window` | Regulate for same-window.  If the user chooses the selected window despite `inhibit-same-window`, bind that entry to nil for this call; otherwise it fails as documented. |
| `display-buffer-reuse-window` | Regulate for reuse.  Respects `reusable-frames` and `inhibit-switch-frame`.  If the user chooses a window the caller excluded, bind `inhibit-same-window` to nil for this call. |
| `display-buffer-reuse-mode-window` | Respect, or regulate as reuse with `mode`.  Open. |
| `display-buffer-pop-up-window` | Regulate for a split action.  Automatic split is open. |
| `display-buffer-in-previous-window` | Respect, or regulate for a "previous window" choice.  Open. |
| `display-buffer-use-some-window` | Regulate: show caller intent info, prompt with `ace-window`, and let the user choose an existing window or a split action.  If the package calls the function, `some-window`, `lru-frames`, `lru-time`, and the minimum sizes apply. |
| `display-buffer-use-least-recent-window` | Respect, or regulate for other-window.  Open. |
| `display-buffer-in-direction` | Regulate for the "use caller intent" direction action.  Respects `direction` and `window`. |
| `display-buffer-below-selected` | Respect. |
| `display-buffer-at-bottom` | Respect. |
| `display-buffer-full-frame` | Respect. |
| `display-buffer-pop-up-frame` | Regulate for a new frame.  Respects `pop-up-frame-function` and `pop-up-frame-parameters`. |
| `display-buffer-use-some-frame` | Regulate for an existing frame.  Respects `frame-predicate` and `inhibit-switch-frame`. |
| `display-buffer-in-child-frame` | Respect. |
| `display-buffer-in-tab` | Regulate for an existing tab.  Respects `reusable-frames` (nil means no search), `tab-name`, `tab-group`, and `ignore-current-tab`. |
| `display-buffer-in-new-tab` | Regulate for a new tab.  Respects `tab-name` and `tab-group`. |
| `display-buffer-in-side-window` | Respect; side as-is. |
| `display-buffer-in-atom-window` | Respect. |
| `display-buffer-no-window` | Regulate: leave undisplayed; only with `allow-no-window`. |

## 8. Action alist checklist

| Entry | Treatment |
|---|---|
| `inhibit-same-window` | Referential.  Show caller intent info; do not remove the selected window from the candidates.  If the user chooses a window the caller excluded, bind this entry to nil for the display call. |
| `previous-window` | Open: pass it through when the caller's action runs; when the package prompts, decide whether to show or prefer the named window. |
| `mode` | Pass to `display-buffer-reuse-mode-window`; open. |
| `frame-predicate` | Frame candidates; respect. |
| `reusable-frames` | Reuse and tab scope; respect.  The tab meaning of nil differs. |
| `inhibit-switch-frame` | Frame raising and focus; respect. |
| `window-parameters` | Apply to the chosen window; delegate to the standard function. |
| `window-min-width`, `window-min-height` | Eligibility constraints; delegate. |
| `window-height`, `window-width`, `window-size` | Delegate; do not reimplement. |
| `dedicated` | Delegate; do not reimplement. |
| `preserve-size` | Delegate. |
| `lru-frames`, `lru-time`, `bump-use-time` | Delegate to `display-buffer-use-some-window` or `display-buffer-use-least-recent-window`. |
| `pop-up-frame-parameters`, `pop-up-frames` | Frame handling; delegate. |
| `parent-frame`, `child-frame-parameters` | Child frame; respect. |
| `side`, `slot` | Side as-is; respect. |
| `direction`, `window` | Direction action; delegate to `display-buffer-in-direction`. |
| `allow-no-window` | Required for leave undisplayed. |
| `some-window` | Other-window strategy; delegate. |
| `body-function` | Must run after display; delegate.  Do not use raw `window--display-buffer` without processing it. |
| `post-command-select-window` | Selection; respect.  The package selection option is open. |
| `category` | Escape hatch and caller intent info; open. |
| `tab-name`, `tab-group`, `ignore-current-tab` | Tab flow; delegate. |

## 9. Context rules

- Batch: return nil.  Do not prompt.
- Active minibuffer: return nil.  Do not prompt.
- Timer, process filter, or keyboard macro: return nil.  Do not prompt.
- Daemon or text terminal: ace-window may still work; the prompt rules
  are the same.  Remote frames are open.
- Recursive display during tab or frame creation, or during a preview:
  guard it and return nil for the nested call.
- Multiple `display-buffer` calls in one command: no cache by default.
  An optional cache for the same buffer is open.
- Failure after the choice: if the window is dead, repeat or decline
  according to the cancellation option; if the frame or tab is gone,
  prompt again; if the display function errors, report it and return
  nil.

## 10. Open decisions

Section 5 lists the policy choices.  The following are the details
still needed for those choices and the remaining open items.

1. Reuse option: name, default, and how several reuse windows are
   chosen or marked.
2. Automatic split: `split-maximum` and its interaction with
   `split-window-preferred-function`, `split-height-threshold`,
   `split-width-threshold`, and `pop-up-windows`.
3. Selection: `post-command-select-window` and the options now in the
   source.
4. C-g: the three values, the abort key, and the fallback when
   `allow-no-window` is nil.
5. Same-window caller intent info: one option or separate options, and
   the exact text.
6. Sole-window dispatch list: which actions are included.
7. Frame and tab candidates, prompt conditions, focus, preview
   restoration, and the no-consult fallback.
8. Whether a caller's ACTION that names a tab or frame prompts, or
   only shows caller intent info; keep caller ACTION and prefix cases
   separate.
9. Placed `window`, `slot`, `parent-frame`, and `child-frame-parameters`
   beyond direction and side.
10. `previous-window`: pass it through, show it as a candidate, or
    prefer it when the package prompts.
11. Action alist entries marked open in section 8.
12. Noninteractive contexts and recursive or multiple display calls.
13. Confirm the new term definitions in `TERM_AND_CONVENTION.md`.

## 11. Test matrix

Every cell in the behavior table needs a Buttercup test.  At minimum,
combine:

- caller intent: same-window, no preference, reuse with a target, reuse
  without a target, other-window, new-window, direction, tab, frame,
  placed, side, ACTION `t`, `switch-to-buffer`;
- window state: selected window eligible, selected window dedicated,
  selected window a side window, selected window a minibuffer window;
- buffer state: already displayed, not displayed;
- target state: existing, new, none;
- caller constraint: none, `inhibit-same-window`, `reusable-frames`,
  `previous-window`, `allow-no-window`;
- user option: each value of the reuse, selection, cancellation, and
  info options.

Also test every action function and action alist entry from sections 7
and 8, and the context rules from section 9.  A missing cell is a known
gap, not an unknown one.
