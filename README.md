# disbuf-pivot

`display-buffer` picks a window from an action list.  The pick is
convenient, but it is made without the user: a utility popup, a dedicated
or side window, a buffer visible in another tab or frame, and a repeated
tab or frame title can all send the buffer to a place the user did not
choose.  disbuf-pivot replaces that implicit pick with an explicit one.

## The display action

`disbuf-pivot-action-mode` adds one entry to `display-buffer-alist`.
For every buffer an earlier entry does not take, the entry:

- leaves a request that names a place -- a window, direction, side, slot,
  or child frame -- to the caller's action functions;
- asks for a tab when the request names a tab, and for a frame when it
  names a frame.  A tab name can come from `tab-name`; a frame name is
  read from the top-level frames.  An empty name makes a new tab or
  frame.  A tab asks for its window when no window in it displays the
  buffer; an existing frame asks for its tab when it has more than one,
  then for its window, while a new frame uses its selected window.  The
  tab and frame window prompt honor `inhibit-same-window` and can split
  a window;
- otherwise tries `disbuf-pivot-action-functions`: reuse a window that
  displays the buffer, the selected window, then split when the split
  rule allows it or ask with `ace-window`.

`disbuf-pivot-action-functions` changes the functions and their order.
`disbuf-pivot-action-select` says whether the window chosen with
`ace-window` is selected.  The action declines in batch, while the
minibuffer is active, when the user cancels, and when no window can
display the buffer; the remaining `display-buffer` rules then apply.

## The prefix commands

`disbuf-pivot-prefix-mode` advises `display-buffer`.  When a prefix has
armed `display-buffer-overriding-action` and the selected window cannot
display the buffer, the mode runs the display in the most recently used
editing window of the frame, or of the parent frame when a child frame is
selected.  The built-in prefixes then act on the editing window, not on
the popup.

The package also provides two prefix commands:

- `disbuf-pivot-other-window-prefix` splits when the split rule allows
  it, and otherwise asks with `ace-window`.  It follows
  `reusable-frames`, passes `inhibit-same-window` as the ignored window,
  and its `disbuf-pivot-other-window-prefix-select` option controls the
  selected window after the choice.
- `disbuf-pivot-other-tab-prefix` reuses a tab that already displays the
  buffer, and otherwise reads a tab name and asks for its window.  A
  display made while the tab is made is left to the other display rules,
  so the tab prompt does not run again.

## The tab reader

`disbuf-pivot-tab-bar-read-tab-name` reads a tab name from the live tabs,
the closed-tab history, the configured sort and the annotations.
`disbuf-pivot-tab-bar-read-function` can replace the plain
`completing-read` reader.  The optional
`disbuf-pivot-tab-bar-consult` library supplies a consult reader with
previews and the mode that installs it.

The reader deletes child frames before it saves the window configuration,
and the consult reader preserves the minibuffer height while a preview
selects a tab; both are PGTK and Corfu workarounds.  The `emacs-utils`
repository consumes the consult library and adds its tab-switch commands
and overrides.

## Requirements and installation

Emacs 31.1 is the tested version.  `ace-window` is required; `avy` is
required by `ace-window`.  Consult is optional and needed only by the
consult reader.  `tab-bar-mode` is needed for tab targets.

Add the repository root to `load-path`, or install the package, then
require the libraries and enable the modes:

```elisp
(require 'disbuf-pivot)
(require 'disbuf-pivot-prefix)
(disbuf-pivot-action-mode +1)
(disbuf-pivot-prefix-mode +1)
```

The commands are `disbuf-pivot-other-window-prefix` and
`disbuf-pivot-other-tab-prefix`.  The optional consult reader is a
separate library:

```elisp
(require 'disbuf-pivot-tab-bar-consult)
(disbuf-pivot-tab-bar-consult-mode +1)
```

## The libraries

- `disbuf-pivot` holds the display action, its options, and the tab and
  frame prompts.
- `disbuf-pivot-window-utility` holds the window test, the split
  options, and the window prompt.
- `disbuf-pivot-prefix` holds the prefix commands and the pivot mode.
- `disbuf-pivot-tab-bar` holds the tab candidates, history, selection
  and plain reader.
- `disbuf-pivot-tab-bar-consult` holds the optional consult reader and
  the mode that installs it.

`disbuf-pivot.el` is the package main file and carries the package
`Package-Requires`; the optional consult library names `consult` in its
Commentary.  The source files use `dp-` as a shorthand for
`disbuf-pivot-`; the public symbols remain full.

## Scope

- The package displays a buffer the caller supplies; it does not make a
  buffer and does not manage popup windows.
- It installs one `display-buffer-alist` entry; a caller's
  `display-buffer-overriding-action` is consulted before it.  A caller
  that needs its own action should name a place or use an overriding
  action.
- The frame prompt offers visible top-level frames only.  A repeated
  frame title is disambiguated, an unknown non-empty name asks again,
  and an empty name makes a new frame.
- The pivot mode searches the selected frame or its parent frame.  A
  utility popup in another frame is not found.  A caller's overriding
  action that is not a prefix is pivoted as well.
- When no other window can display the buffer, the other-window prefix
  can use the selected window rather than fail.
- The tests cover the action, the prefix commands, the tab and frame
  targets, and the tab reader.  The consult preview is checked by
  compilation and checkdoc, not by a full preview test.

## Development

`make check` byte-compiles the package and runs the buttercup tests under
`test/`.  `make check-consult` compiles and checks the optional consult
library.  `make checkdoc` reports the docstring findings.  The test files
keep the `check` harness they had in `emacs-utils`.

## Naming and license

The package name shortens display-buffer pivot; `disbuf` is not an Emacs
term.  The repository keeps the full name `display-buffer-pivot`.
GPL-3.0-or-later; see `LICENSE`.
