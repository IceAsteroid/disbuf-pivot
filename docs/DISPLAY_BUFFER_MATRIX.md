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

## 1. Reuse and selection

| Function | Decision | `inhibit-same-window` | `reusable-frames` | `inhibit-switch-frame` | `previous-window` | `reuse-indirect` | `mode` |
|---|---|---|---|---|---|---|---|
| `display-buffer-same-window` | Regulate | Y | - | - | - | - | - |
| `display-buffer-reuse-window` | Regulate | Y | Y | Y | - | Y | - |
| `display-buffer-reuse-mode-window` | Regulate | Y | Y | Y | - | - | Y |
| `display-buffer-pop-up-window` | Regulate | - | - | Y | - | - | - |
| `display-buffer-in-previous-window` | Respect | Y | Y | - | Y | - | - |
| `display-buffer-use-some-window` | Regulate | Y | - | Y | - | - | - |
| `display-buffer-use-least-recent-window` | Regulate | P* | Y | Y | - | - | - |
| `display-buffer-in-direction` | Regulate | - | - | - | - | - | - |
| `display-buffer-below-selected` | Respect | - | - | - | - | - | - |
| `display-buffer-at-bottom` | Respect | - | - | - | - | - | - |
| `display-buffer-full-frame` | Respect | - | - | - | - | - | - |
| `display-buffer-pop-up-frame` | Respect | - | - | Y | - | - | - |
| `display-buffer-use-some-frame` | Respect | Y | - | Y | - | - | - |
| `display-buffer-in-child-frame` | Respect | - | - | - | - | - | - |
| `display-buffer-in-tab` | Respect | - | Y | - | - | - | - |
| `display-buffer-in-new-tab` | Respect | - | - | - | - | - | - |
| `display-buffer-in-side-window` | Respect | - | - | - | - | - | - |
| `display-buffer-in-atom-window` | Respect | - | - | - | - | - | - |
| `display-buffer-no-window` | Regulate | - | - | - | - | - | - |

`P*`: `display-buffer-use-least-recent-window` adds
`(inhibit-same-window . t)` internally and never uses the selected
window.  The tab meaning of `reusable-frames` differs: nil means do not
search any frames.

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
| `display-buffer-in-child-frame` | - | - | - | - | - | Y | Y | - | - | - | - | - | - |
| `display-buffer-in-tab` | - | - | - | - | - | - | - | - | - | Y | Y | Y | - |
| `display-buffer-in-new-tab` | - | - | - | - | - | - | - | - | - | Y | Y | - | - |
| `display-buffer-no-window` | - | - | - | - | - | - | - | - | - | - | - | - | Y |
| All other functions | - | - | - | - | - | - | - | - | - | - | - | - | - |

`pop-up-frames` is a target selector, not an alist read by
`display-buffer-pop-up-frame`.  The fallback action and the package's
target detection use it to choose a frame strategy.

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

Show caller intent info, call the window prompt, keep the selected
window a candidate, and bind the entry to nil for the display call if
the user chooses it.  `display-buffer-use-least-recent-window` forces it
internally; the selected window is not a candidate for that function.

## 6. Verification notes

The Emacs 31.1 source confirms three cells the docstrings leave out:
`display-buffer-in-previous-window` does not read
`inhibit-switch-frame`; `display-buffer-use-some-window` does not read
`reusable-frames`; `display-buffer-in-tab` does not read
`inhibit-same-window`.

- `display-buffer-pop-up-window` and the size entries: the manual says
  it honors `window-height`, `window-width`, and `preserve-size`; the
  docstring delegates to the manual.  The shared table treats them as
  generic entries.
