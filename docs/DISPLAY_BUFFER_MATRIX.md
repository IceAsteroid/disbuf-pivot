# Emacs display-buffer action matrix

Status: reference for the design.  This file is not normative.  It
records the Emacs 31.1 action-function and action-alist matrix and the
package's treatment, so the rules in `docs/DESIGN_RULESET.md` can be
checked against Emacs.

Source: the Emacs 31.1 docstrings, the Elisp manual nodes
`(elisp) Buffer Display Action Functions` and
`(elisp) Buffer Display Action Alists`, and the Emacs 31.1
`window.el.gz` and `tab-bar.el.gz` sources.

## Legend

- `Y` -- the function's docstring or manual entry documents this use.
- `P` -- a policy of the function, not a direct alist read.
- `P*` -- the function forces the entry internally.
- `G` -- the generic display machinery applies the entry to the chosen
  window; see the shared table.
- `-` -- not documented for that function.  It may still be ignored or
  handled generically; verify the source before relying on it.
- `?` -- not verified.
- Decision -- the package treatment: `Regulate` or `Respect`.

The Decision column applies when the listed function is the effective
function in the caller's ACTION (including after a reuse-first function
finds no matching window; see `docs/DESIGN_RULESET.md` section 3).

## 1. Reuse and selection

| Function | Decision | `inhibit-same-window` | `reusable-frames` | `inhibit-switch-frame` | `previous-window` | `reuse-indirect` | `mode` |
|---|---|---|---|---|---|---|---|
| `display-buffer-same-window` | Regulate | Y | - | - | - | - | - |
| `display-buffer-reuse-window` | Regulate | Y | Y | Y | - | Y | - |
| `display-buffer-reuse-mode-window` | Regulate | Y | Y | Y | - | - | Y |
| `display-buffer-pop-up-window` | Regulate | - | - | Y | - | - | - |
| `display-buffer-in-previous-window` | Regulate | Y | Y | - | Y | - | - |
| `display-buffer-use-some-window` | Regulate | Y | - | Y | - | - | - |
| `display-buffer-use-least-recent-window` | Regulate | P* | Y | Y | - | - | - |
| `display-buffer-in-direction` | Regulate | - | - | - | - | - | - |
| `display-buffer-below-selected` | Regulate | - | - | - | - | - | - |
| `display-buffer-at-bottom` | Regulate | - | - | - | - | - | - |
| `display-buffer-full-frame` | Regulate | - | - | - | - | - | - |
| `display-buffer-pop-up-frame` | Regulate | - | - | Y | - | - | - |
| `display-buffer-use-some-frame` | Regulate | Y | - | Y | - | - | - |
| `display-buffer-in-child-frame` | Respect | - | - | Y | - | - | - |
| `display-buffer-in-tab` | Regulate | - | Y | - | - | - | - |
| `display-buffer-in-new-tab` | Regulate | - | - | - | - | - | - |
| `display-buffer-in-side-window` | Respect | - | - | - | - | - | - |
| `display-buffer-in-atom-window` | Respect | - | - | - | - | - | - |
| `display-buffer-no-window` | Regulate | - | - | - | - | - | - |

`P*`: `display-buffer-use-least-recent-window` adds
`(inhibit-same-window . t)` internally and never uses the selected
window.  The tab meaning of `reusable-frames` differs: nil means do not
search any frames.

`display-buffer-full-frame` delegates to `display-buffer-reuse-window`,
`display-buffer-same-window`, `display-buffer-pop-up-window`, and
`display-buffer-use-some-window` in that order, so their entries apply.

`display-buffer-in-previous-window` is Regulate: the `previous-window`
entry is a preferred candidate, and without a usable entry, the first
previous-buffer window is not visible to the user.

`display-buffer-below-selected` and `display-buffer-at-bottom` are
Regulate: they are relative placements; the prompt offers the caller's
function as the "use caller intent" action.

The tab or frame actions are Regulate: the tab prompt or frame prompt
preselects an existing tab or frame; a new one starts without an
existing preselect.  The child-frame action,
`display-buffer-in-child-frame`, remains Respect.

## 2. Window fit and strategy

| Function | `some-window` | `lru-frames` | `lru-time` | `window-min-width` | `window-min-height` |
|---|---|---|---|---|---|
| `display-buffer-use-some-window` | Y | Y | Y | Y | Y |
| `display-buffer-use-least-recent-window` | - | Y | Y | Y | Y |
| `display-buffer-below-selected` | - | - | - | - | Y |
| All other functions | - | - | - | - | - |

`display-buffer-use-some-window` passes `lru-frames` and
`window-min-width` defaults to `display-buffer--lru-window`; a caller
entry takes precedence.  `display-buffer-use-least-recent-window`
chooses the least recently used window and falls back to
`display-buffer-pop-up-window`.

## 3. Placement and tab/frame alists

| Function | `direction` | `window` | `frame-predicate` | `pop-up-frame-parameters` | `pop-up-frames` | `parent-frame` | `child-frame-parameters` | `side` | `slot` | `tab-name` | `tab-group` | `ignore-current-tab` | `allow-no-window` |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `display-buffer-in-direction` | Y | Y | - | - | - | - | - | - | - | - | - | - | - |
| `display-buffer-in-side-window` | - | - | - | - | - | - | - | Y | Y | - | - | - | - |
| `display-buffer-in-atom-window` | - | Y | - | - | - | - | - | Y | - | - | - | - | - |
| `display-buffer-use-some-frame` | - | - | Y | - | - | - | - | - | - | - | - | - | - |
| `display-buffer-pop-up-frame` | - | - | - | Y | - | - | - | - | - | - | - | - | - |
| `display-buffer-in-child-frame` | - | - | - | - | - | - | Y | - | - | - | - | - | - |
| `display-buffer-in-tab` | - | - | - | - | - | - | - | - | - | Y | Y | Y | - |
| `display-buffer-in-new-tab` | - | - | - | - | - | - | - | - | - | Y | Y | - | - |
| `display-buffer-no-window` | - | - | - | - | - | - | - | - | - | - | - | - | Y |
| All other functions | - | - | - | - | - | - | - | - | - | - | - | - | - |

`pop-up-frames` is a target selector, not an alist read by
`display-buffer-pop-up-frame`.  The fallback action and the package's
target detection use it to choose a frame strategy.  The reuse
functions read it through `window--pop-up-frames` when
`reusable-frames` has no entry.

## 4. Shared entries

These entries are handled by the generic display path, not by one
function's own logic:

| Entry | Treatment |
|---|---|
| `window-parameters`, `dedicated`, `preserve-size`, `window-height`, `window-width`, `window-size` | Apply to the chosen window through the standard display path. |
| `bump-use-time` | Bump the chosen window's use time; handled by `window--display-buffer`. |
| `body-function` | Run after the buffer is displayed. |
| `post-command-select-window` | Select or restore the window after the command. |
| `category` | Pass through; use in caller intent info when present. |
| `inhibit-same-window` | Policy for functions that reuse or use an existing window; see table 1 and the package treatment below. |
| `allow-no-window` | Only `display-buffer-no-window`; it permits the `fail` return. |

## 5. Package treatment of `inhibit-same-window`

Show the entry in header info (caller intent info or source-labeled
entries), prompt by the rules in `docs/DESIGN_RULESET.md` sections 2–5,
keep the selected window eligible whenever it is displayable, and bind
`inhibit-same-window` to nil for the display call if the user chooses
it.  `display-buffer-use-least-recent-window` forces
`(inhibit-same-window . t)` internally when Emacs runs it, so choosing
`"Use caller intent"` avoids the selected window, while choosing the
selected window's label explicitly overrides it.

## 6. Verification notes (Emacs 31.1 source)

- **Alist reads verified in `window.el.gz` and `tab-bar.el.gz`**:
  `display-buffer-in-previous-window` does not read
  `inhibit-switch-frame` and dereferences a bound symbol in
  `previous-window` (`window.el.gz:9159`);
  `display-buffer-use-some-window` does not read `reusable-frames`;
  `display-buffer-in-tab` does not read `inhibit-same-window`;
  `display-buffer-in-child-frame` reads `inhibit-switch-frame` and reads
  `parent-frame` inside `child-frame-parameters` rather than top-level
  (`window.el.gz:8807`); `display-buffer-reuse-mode-window` defaults to
  the buffer's `major-mode` when `mode` is omitted (`window.el.gz:8621`).
- **Non-list `ACTION` clearing (`window.el.gz:8176`)**:
  `display-buffer` clears any non-list `ACTION` (such as `t` or
  `'other-window`) to `nil` *before* calling `display-buffer-assq-regexp`
  and puts `(inhibit-same-window . t)` into `extra-action` (along with
  `(reusable-frames . FRAME)` for the optional third argument).
- **Reuse-first built-in action (`window.el.gz:8439`)**:
  `display-buffer--other-frame-action` (used by `display-buffer-other-frame`
  and `switch-to-buffer-other-frame`) is
  `((display-buffer-reuse-window display-buffer-pop-up-frame)
  (reusable-frames . 0) (inhibit-same-window . t))`.
- **`display-buffer--special-action` (`window.el.gz:8693`)**:
  always returns a display action with a `nil` action alist.
- **`display-buffer-same-window` (`window.el.gz:8489`)**:
  rejects any dedicated window (even one dedicated to the buffer being
  displayed) and does not check `window-side`.
- **`display-buffer-in-tab` (`tab-bar.el.gz:2995`)**:
  when selecting an existing tab matching `tab-name` that does not
  already show the buffer, selects that tab and returns `nil`.
- **`display-buffer-in-direction` (`window.el.gz:8985`)**:
  appends `(window-height . fit-window-to-buffer)` (or
  `resize-temp-buffer-window` and `preserve-size`) to `alist` if absent.
- **`window--display-buffer` `TYPE` & `display-buffer-mark-dedicated`
  (`window.el.gz:6996, 7757`)**:
  `dedicated`, `window-height`, `window-width`, `preserve-size`, and
  window-deleting `quit-restore` apply only for `type = 'window` (new
  window on existing frame); `window-size` applies only for
  `type = 'frame`.  When `dedicated` is absent from `alist`,
  `display-buffer-mark-dedicated` still applies for new windows; an
  explicit `(dedicated . nil)` inhibits it.
- **`display-buffer-override-next-command` (`window.el.gz:9751`)**:
  unconditionally calls `(window--display-buffer buffer window type
  alist)` with the original unmodified `alist` after `pre-function`
  returns.
- **`split-window` on dedicated vs. side windows**:
  splitting a hard-dedicated normal window succeeds and makes a
  non-dedicated new window while leaving the original window dedicated;
  splitting a side window signals `"Cannot split side window or parent
  of side window"`.
- **`display-buffer-pop-up-window` and size entries**: the manual says
  it honors `window-height`, `window-width`, and `preserve-size`; the
  docstring delegates to the manual.  The shared table treats them as
  generic entries applied via `window--display-buffer`.
