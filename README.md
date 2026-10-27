# disbuf-pivot

Choose where to display a buffer when the selected window cannot
display it: a window, a tab or a frame.  The package holds the display
action mode, the window utility, the window prefix commands and the tab
bar reader.

The package is `disbuf-pivot`; `disbuf` is the short form of
`display-buffer`, and the pivot is the display target.  The repository
is `display-buffer-pivot`.

## Requirements

Emacs 31.1 is the tested version.  `ace-window` is required; `avy` is
required by `ace-window`.  Consult is optional: the
`disbuf-pivot-tab-bar-consult` library requires it.

## Installation

Clone the repository and add its root to `load-path`, or install it as
a package.  Require the library you need:

```elisp
(require 'disbuf-pivot)
(require 'disbuf-pivot-window-prefix)
(disbuf-pivot-action-mode +1)
```

The commands and modes are `disbuf-pivot-action-mode`,
`disbuf-pivot-other-window-prefix`,
`disbuf-pivot-other-tab-prefix` and
`disbuf-pivot-window-prefix-mode`.
`disbuf-pivot-action-mode` installs one entry in
`display-buffer-alist`; `disbuf-pivot-window-prefix-mode`
installs the pivot.

## The libraries

- `disbuf-pivot` chooses the window and holds the action
  functions and the tab and frame prompts.
- `disbuf-pivot-window-utility` holds the window test, the
  split options and the window prompt.
- `disbuf-pivot-window-prefix` holds the window prefix
  commands and the pivot.
- `disbuf-pivot-tab-bar` holds the tab candidates, history and
  reader.
- `disbuf-pivot-tab-bar-consult` holds the optional consult
  reader and the mode that installs it.

`disbuf-pivot.el` is the package main file and carries the
`Package-Requires` header.  The other libraries are loaded with
`require`; their `Author`, `URL` and `SPDX` headers are comments.

The source files use `dp-` as a shorthand for `disbuf-pivot-`; the
public symbols remain full.

## Completion

`disbuf-pivot-tab-bar-read-tab-name` reads a tab name with
`completing-read`.  The optional
`disbuf-pivot-tab-bar-consult` library supplies a consult
reader with previews and the mode that installs it:

```elisp
(require 'disbuf-pivot-tab-bar-consult)
(disbuf-pivot-tab-bar-consult-mode +1)
```

The reader deletes child frames before saving the window state and
preserves the minibuffer height while a preview selects a tab; both are
PGTK workarounds.  The library requires `consult`; the core package does
not.  Consult is not in the package's main `Package-Requires`; install it
separately.  The `ia-tab-bar-modified-consult` integration in the
`emacs-utils` repository consumes this library and adds its tab-switch
commands and overrides.  A completion frontend can also set
`disbuf-pivot-tab-bar-read-function` directly.

## column-popup

This package does not manage popup windows; `column-popup` does.  Its
windows are dedicated, so
`disbuf-pivot-window-utility-cannot-display-p` declines them,
and the display action leaves them alone.

## Development

`make check` byte-compiles the core package and runs the buttercup tests
under `test/`.  `make checkdoc` reports the docstring findings; the two
keycode literals in the action and the window utility are the
maintainer's choice.  `make check-consult` compiles and checks the
optional consult library; it needs consult.  The test files keep the
`check` harness they had in `emacs-utils`.

## License

GPL-3.0-or-later; see `LICENSE`.
