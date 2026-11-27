# disbuf-pivot

`display-buffer` picks a window from an action list.  The pick is
convenient, but it is made without the user.  A dedicated window, a side
window, or a child frame can send the display to an unintended window or
frame; a buffer visible in another tab or frame can be reused; and a
repeated tab or frame name can be ambiguous.  The buffer can then appear
in a place the user did not choose.  disbuf-pivot replaces that implicit
pick with an explicit one.  The *pivot* is the point at which the package
either respects the effective intent or replaces that intent with the
user's explicit choice.

## The package's `display-buffer-alist` entry

`disbuf-pivot-action-mode` adds one entry to `display-buffer-alist`.
For every non-excluded buffer an earlier entry does not take, the entry
classifies the effective intent (covering all 19 Emacs 31.1
`display-buffer-*` action functions, reuse-first chains such as
`display-buffer--other-frame-action`, non-list `ACTION` values, and
dynamic `pop-up-frames` and `display-buffer-reuse-frames`):

- respects fixed-place requests (`display-buffer-in-side-window`,
  `display-buffer-in-atom-window`, `display-buffer-in-child-frame`) and
  any uncovered action function by returning nil without prompting;
- returns `fail` without prompting for `display-buffer-no-window` when
  `allow-no-window` is non-nil (otherwise continues to any later
  function in the caller's function list or no preference);
- handles reuse-first chains (`display-buffer-reuse-window` and
  `display-buffer-reuse-mode-window`, honoring `reusable-frames`,
  `reuse-indirect` including `'buffer` no-swap semantics, `mode`
  defaulting to the buffer's `major-mode` with 4-tier priority,
  `pop-up-frames`, and `display-buffer-reuse-frames`): when a reusable
  window exists, `disbuf-pivot-reuse` (`auto` or `ask`) either reuses it
  silently or opens the dispatch prompt (offering `"Reuse in frame
  NAME"` when the preferred reuse window is on another frame); when none
  exists, the classifier continues with the next function in the
  caller's function list;
- runs the tab prompt or frame prompt for tab or frame actions
  (`display-buffer-in-tab`, `display-buffer-in-new-tab`,
  `display-buffer-pop-up-frame`, `display-buffer-use-some-frame`),
  `tab-name`, `tab-group`, or effective `pop-up-frames`.  A tab name can
  come from `tab-name`; a frame name is read from live visible top-level
  frames.  An existing name selects the tab or frame; an empty name makes
  a new tab or frame; any other name makes a new tab or frame with that
  name.  An existing frame asks for its tab when `tab-bar-mode` is
  active or it has more than one; a new frame uses its selected tab;
- displays directly in a displayable selected window for
  `display-buffer-same-window` when not inhibited; reports conflicts
  with `inhibit-same-window` under `disbuf-pivot-same-window-conflict`
  (`ask` or `same-window`); and opens the dispatch prompt when the
  selected window cannot display;
- regulates strategy, relative placement, `display-buffer-full-frame`
  (where window labels display normally without deleting other windows,
  while `"Display full frame"` runs the caller's full-frame action),
  `display-buffer-in-previous-window` (dereferencing bound variable
  symbols in `previous-window` and consulting `disbuf-pivot-reuse` when
  no previous window is usable), and empty-function `inhibit-same-window`
  calls (including non-list `ACTION` such as `t` or `'other-window`,
  keeping the selected window eligible and binding `inhibit-same-window`
  to nil if chosen) through the synchronous dispatch prompt;
- otherwise runs `disbuf-pivot-action-functions` (default: regulated
  `display-buffer-reuse-window`, regulated `display-buffer-same-window`,
  and `disbuf-pivot-action-choose-window`), propagating exact
  `window--display-buffer` `TYPE` values (`'reuse`, `'window`, `'tab`,
  `'frame`), showing formatted header info (`Caller (<category>): ...`,
  source-labeled entries, and window facts), and recovering cleanly from
  failure after the choice (re-prompting on dead windows, frames, or
  vanished tabs; reporting and returning `fail` when a display primitive
  returns nil; propagating errors).

`disbuf-pivot-action-functions` changes the functions and their order.
`disbuf-pivot-action-select` (default `auto`) says whether the window
chosen with the dispatch prompt is selected.  The dispatch prompt draws
window labels on every window in the window label scope
(`disbuf-pivot-eligible-label` and `disbuf-pivot-ineligible-label`
faces) and shows the dispatch prompt menu directly via
`display-buffer-in-side-window` with three responsive, logically wrapped
groups (`Windows`, `Dispatch actions`, and `Window settings`), governed
by `disbuf-pivot-window-keys` (digits `1`–`9` by default with uniform
fixed-width multi-key overflow), `disbuf-pivot-split-actions` (`b` Split
below, `r` Split right, `f` Split fair; splits a sole splittable window
immediately or reads a splittable target when more than one exists),
`disbuf-pivot-header-info` (always showing the dispatch prompt default
when present), `disbuf-pivot-menu-min-column-width` (`20`), and
`disbuf-pivot-menu-min-height` (`5`).  Tall menus scroll via standard
Emacs `scroll-other-window` / `scroll-other-window-down` bindings
without changing `selected-window`; frames below the minimum width or
height keep window labels drawn and fall back to a compact echo-area
prompt.  Present window-setting entries (`dedicated`,
`window-parameters`, `preserve-size`, `window-height`, `window-width`,
`window-size`) get fixed `M-1`..`M-6` toggles plus `M-0` (`All`),
shadowing disabled entries locally with `(KEY . nil)`.  `M-c` runs the
caller's function list under a recursion guard, `M-n` leaves the buffer
undisplayed (`fail`, when `allow-no-window` is non-nil), `M-b` bypasses
the pivot (nil choice), and `C-g` aborts without running later action
functions.

`disbuf-pivot-exclude-conditions` lists `buffer-match-p` conditions
(regexp, `derived-mode`, `major-mode`, `category`, `this-command`,
predicate, `not`/`and`/`or`); `disbuf-pivot-action-control-p` passes
the caller's `ACTION` as the third argument to `buffer-match-p` so
`category` conditions match, and a matching buffer is left to later
`display-buffer-alist` entries and Emacs display actions.  Pressing an
ineligible window label reports why in the echo area and keeps the
prompt open; a non-side window dedicated to the buffer being displayed
is displayable.  The action returns nil in cannot-prompt contexts --
batch (`noninteractive`), an active minibuffer, keyboard macro
execution (`executing-kbd-macro`), timers, process filters and
sentinels, and recursive display (during an open prompt, tab or frame
creation, or consult preview) -- so later functions in Emacs's combined
function list run.

`disbuf-pivot-tab-prompt-scope` is defined ahead of the upcoming
tab-scope milestone.

## The prefix commands

`disbuf-pivot-prefix-mode` is a global minor mode that remaps the
built-in prefix commands to the package commands.  While it is enabled,
the bindings of `same-window-prefix`, `other-window-prefix`,
`other-tab-prefix`, and `other-frame-prefix` run
`disbuf-pivot-same-window-prefix`,
`disbuf-pivot-other-window-prefix`,
`disbuf-pivot-other-tab-prefix`, and
`disbuf-pivot-other-frame-prefix`.  When the mode is disabled, the
built-in bindings return.  The mode changes key bindings; a built-in
command invoked by name or from a menu is unchanged.

The package provides four prefix commands.  Each uses the most recently
used displayable window of the frame, or of the parent frame when a child
frame is selected, when the selected window cannot display a buffer.

- `disbuf-pivot-same-window-prefix` displays the buffer in the same
  window.
- `disbuf-pivot-other-window-prefix` splits when
  `disbuf-pivot-window-utility-split-p` allows it, and otherwise opens
  the dispatch prompt.  It follows `reusable-frames`, passes
  `inhibit-same-window` as the excluded window, and its
  `disbuf-pivot-other-window-prefix-select` option controls the
  selected window after the choice.
- `disbuf-pivot-other-tab-prefix` reuses a tab that already displays the
  buffer, and otherwise reads a tab name and asks for its window.  A
  display made while the tab is made is left to the other display rules,
  so the tab prompt does not run again.
- `disbuf-pivot-other-frame-prefix` asks for a frame.  For an existing
  frame it asks for its tab when `tab-bar-mode` is active or the frame
  has more than one, then for its window; a new frame uses its selected
  window.  A new frame name makes a new frame with that name; an empty
  name makes a new frame with the default name.

## Reading a tab name

`disbuf-pivot-tab-bar-read-tab-name` reads a tab name from the tabs on
the tab bar, the closed-tab history, the configured sort and the
annotations.  `disbuf-pivot-tab-bar-read-function` can replace the
plain tab reader.  The optional `disbuf-pivot-tab-bar-consult` library
supplies the consult tab reader with previews and the mode that
installs it.

The consult tab reader deletes child frames before it saves the window
configuration, because the PGTK build of Emacs deadlocks when that
configuration contains invisible Corfu frames.  It also preserves the
minibuffer height while a preview selects a tab.  The `emacs-utils`
repository consumes the consult library and adds its tab-switch commands
and overrides.

## Requirements and installation

Emacs 31.1 is the tested version.  The core dispatch prompt has no
runtime dependency on `ace-window`, though `Package-Requires` and
`Makefile` currently still list `ace-window` (with `avy`) until the
dependency cleanup milestone.  Consult is optional and needed only by
the consult tab reader.  `tab-bar-mode` is needed for tab targets.

Add the repository root to `load-path`, or install the package, then
require the libraries and enable the modes:

```elisp
(require 'disbuf-pivot)
(require 'disbuf-pivot-prefix)
(disbuf-pivot-action-mode +1)
(disbuf-pivot-prefix-mode +1)
```

The commands are `disbuf-pivot-same-window-prefix`,
`disbuf-pivot-other-window-prefix`,
`disbuf-pivot-other-tab-prefix`, and
`disbuf-pivot-other-frame-prefix`.  The optional consult tab reader is
a separate library:

```elisp
(require 'disbuf-pivot-tab-bar-consult)
(disbuf-pivot-tab-bar-consult-mode +1)
```

## The libraries

- `disbuf-pivot` holds the package's `display-buffer-alist` entry, its
  options, and the tab and frame prompts.
- `disbuf-pivot-window-utility` holds the window predicates,
  cannot-prompt guards, own window-labeling overlays, split primitives,
  and synchronous dispatch prompt menu.
- `disbuf-pivot-prefix` holds the prefix commands and the prefix mode.
- `disbuf-pivot-tab-bar` holds the tab candidates, history, selection
  and the plain tab reader.
- `disbuf-pivot-tab-bar-consult` holds the consult tab reader and the
  mode that installs it.

`disbuf-pivot.el` is the package main file and carries the package
`Package-Requires`; the optional consult library names `consult` in its
Commentary.  The source files use `dp-` as a shorthand for
`disbuf-pivot-`; the public symbols remain full.

## Scope

- The package displays a buffer the caller supplies; it does not make a
  buffer and does not manage pop-up windows.
- For pop-up windows, pair the package with a package such as
  `column-popup` or `popper`.  Enable `disbuf-pivot` first and that
  package second, so its `display-buffer-alist` entry comes before the
  `disbuf-pivot` entry.  That package handles its pop-up buffers;
  `disbuf-pivot` handles the other buffers.
- It installs one `display-buffer-alist` entry; a caller's
  `display-buffer-overriding-action` is consulted before it.  A caller
  that needs its own action should name a place or use an overriding
  action.
- The frame prompt offers visible top-level frames only.  A repeated
  frame name is disambiguated; a new name makes a new frame with that
  name; an empty name makes a new frame.
- The prefix commands search the selected frame, or its parent frame
  when a child frame is selected.  A window in another frame is not
  searched.  A caller's overriding action that is not one of these
  commands is not changed.
- When no other window can display the buffer, the other-window prefix
  can use the selected window rather than fail.
- The tests cover the action, the prefix commands, the tab and frame
  targets, and the plain tab reader.  The consult preview is checked by
  compilation and checkdoc, not by a full preview test.

## Development

`make check` byte-compiles the package and runs the buttercup tests under
`test/`.  `make check-consult` compiles and checks the optional consult
library.  `make checkdoc` reports the docstring findings.  The test files
keep the `check` harness they had in `emacs-utils`.  The developer,
git, and changelog guide is in `CONTRIBUTING.md`; coding agents start
at `AGENTS.md`.  The term and documentation conventions, design rules,
and Emacs action matrix are under `docs/`.

## Naming and license

The package and repository are `disbuf-pivot`; `disbuf` is the short
form of `display-buffer` and is not an Emacs term.  The name uses
*pivot* as defined above.  GPL-3.0-or-later; see `LICENSE`.
