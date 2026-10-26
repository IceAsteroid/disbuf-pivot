# display-buffer-pivot

Choose the window of a buffer the selected window cannot display.  The
package holds the display action mode, the window utility, the window
prefix pivot and the tab bar reader.

## Requirements

Emacs 31.1 is the tested version.  `ace-window` is required; `avy` is
required by `ace-window`.

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

## Completion

`display-buffer-pivot-tab-bar-read-tab-name` reads a tab name with
`completing-read`.  A completion frontend can set
`display-buffer-pivot-tab-bar-read-function` to a function that reads
the name with its own candidates and previews; it receives the prompt,
the candidate alist and the initial input.  The
`ia-tab-bar-modified-consult` integration in the `emacs-utils`
repository sets that function to a consult reader when
`ia/tab-bar-modified-consult-mode` is enabled.

## column-popup

This package does not manage popup windows; `column-popup` does.  Its
windows are dedicated, so
`display-buffer-pivot-window-utility-cannot-display-p` declines them,
and the display action leaves them alone.

## Development

`make check` byte-compiles the package and runs the buttercup tests
under `test/`.  `make checkdoc` reports the docstring findings; the two
keycode literals in the action and the window utility are the
maintainer's choice.  The test files keep the `check` harness they had
in `emacs-utils`.

## License

GPL-3.0-or-later; see `LICENSE`.
