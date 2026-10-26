# display-buffer-pivot

Choose the window of a buffer the selected window cannot display.  The
package holds the display action mode, the window utility, the window
prefix pivot and the tab bar reader.

## Requirements

Emacs 31.1 is the tested version.  `ace-window` is required; `avy` is
required by `ace-window`.  Consult is optional: the
`display-buffer-pivot-tab-bar-consult` library requires it.

## Installation

Clone the repository and add its root to `load-path`, or install it as
a package.  Require the library you need:

```elisp
(require 'display-buffer-pivot)
(require 'display-buffer-pivot-window-prefix-pivot)
(display-buffer-pivot-action-mode +1)
```

The commands and modes are `display-buffer-pivot-action-mode`,
`display-buffer-pivot-window-prefix-pivot-other-window-prefix`,
`display-buffer-pivot-window-prefix-pivot-other-tab-prefix` and
`display-buffer-pivot-window-prefix-pivot-mode`.
`display-buffer-pivot-action-mode` installs one entry in
`display-buffer-alist`; `display-buffer-pivot-window-prefix-pivot-mode`
installs the pivot.

## The libraries

- `display-buffer-pivot` chooses the window and holds the action
  functions and the tab and frame prompts.
- `display-buffer-pivot-window-utility` holds the window test, the
  split options and the window prompt.
- `display-buffer-pivot-window-prefix-pivot` holds the window prefix
  commands and the pivot.
- `display-buffer-pivot-tab-bar` holds the tab candidates, history and
  reader.
- `display-buffer-pivot-tab-bar-consult` holds the optional consult
  reader and the mode that installs it.

## Completion

`display-buffer-pivot-tab-bar-read-tab-name` reads a tab name with
`completing-read`.  The optional
`display-buffer-pivot-tab-bar-consult` library supplies a consult
reader with previews and the mode that installs it:

```elisp
(require 'display-buffer-pivot-tab-bar-consult)
(display-buffer-pivot-tab-bar-consult-mode +1)
```

The reader deletes child frames before saving the window state and
preserves the minibuffer height while a preview selects a tab; both are
PGTK workarounds.  The library requires `consult`; the core package does
not.  The `ia-tab-bar-modified-consult` integration in the `emacs-utils`
repository consumes this library and adds its tab-switch commands and
overrides.  A completion frontend can also set
`display-buffer-pivot-tab-bar-read-function` directly.

## column-popup

This package does not manage popup windows; `column-popup` does.  Its
windows are dedicated, so
`display-buffer-pivot-window-utility-cannot-display-p` declines them,
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
