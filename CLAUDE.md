# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Prose and terms

`TERM_AND_CONVENTION.md` is the authority for every reply, Commentary,
docstring, `README.md`, `CHANGELOG.md`, and commit message. Read it,
`AGENTS.md`, and `DESIGN_RULESET.md` before changing code or describing
a change. Use the Core terms as defined, avoid the forms in Terms not
used, and do not introduce a term or preferred wording without asking
the maintainer first.

Wrap docstrings at 80 columns and commit-message lines at about 72.
Commits use one atomic change each, with a `feat:`, `fix:`, `refactor:`,
`docs:`, or `test:` subject, and stage explicit paths. Do not rewrite an
existing commit.

## Commands

```sh
make check           # byte-compile CHECK_FILES, then eldev test
make test            # eldev test only
make checkdoc        # checkdoc each CHECK_FILES entry
make check-consult   # compile and checkdoc the optional consult library
```

- `make check` finds `ace-window` and `avy` under `ELPA`
  (`$(HOME)/.emacs.d/elpa` by default; override with `make ELPA=...`).
  `make check-consult` also needs `consult`.
- `make check-consult` does not run tests.
- One test file: `eldev test -f order-test.el`.
- One spec: `eldev test -f order-test.el "ia display action ordering"`.
  Eldev selectors match Buttercup suite and spec names; `--file`
  restricts the loaded files. Each test file defines one `describe` and
  one `it`, so the file option is usually enough.
- CI (`.github/workflows/test.yml`) runs `make check`, `make checkdoc`,
  and `make check-consult` on Emacs 31.1.
- Interactive prompts need a pty. Reproduce them with `emacs -Q` and a
  minimal file under `/tmp`; do not load the user's init or desktop.

## Architecture

The repository is five Emacs Lisp libraries; each non-main library
provides a feature and names optional dependencies in its Commentary.
Only `disbuf-pivot.el` carries `Package-Requires`.

```text
disbuf-pivot.el (feature disbuf-pivot)
├── disbuf-pivot-window-utility.el (dp-window-utility)
├── disbuf-pivot-tab-bar.el (dp-tab-bar)
└── ace-window, tab-bar

disbuf-pivot-prefix.el (dp-prefix)
├── disbuf-pivot
└── disbuf-pivot-window-utility

disbuf-pivot-tab-bar-consult.el (dp-tab-bar-consult, optional)
├── disbuf-pivot-tab-bar
└── consult
```

- `disbuf-pivot.el` holds the display action, its options, the tab and
  frame prompts, and `disbuf-pivot-action-mode`.
- `disbuf-pivot-window-utility.el` holds the window test, the split
  rule and its options, the window prompt, and the post-command
  selection.
- `disbuf-pivot-tab-bar.el` holds tab candidates, history, sort,
  annotations, tab selection, and the plain tab reader.
- `disbuf-pivot-prefix.el` holds the four prefix commands and the global
  minor mode that remaps the built-in prefix commands through a keymap;
  it does not advise `display-buffer`.
- `disbuf-pivot-tab-bar-consult.el` holds the consult tab reader and the
  mode that installs it.

The source files set `read-symbol-shorthands` to `(("dp-" .
"disbuf-pivot-"))`, so `dp-` prefixes abbreviate `disbuf-pivot-`; public
symbols remain full. The Custom groups are `dp-action`, `dp-tab-bar`,
`dp-prefix`, and, in the window library, `windows`.

### The display action

`disbuf-pivot-action-mode` conses one entry,
`(dp-action-control-p . (dp-action--display))`, at the front of
`display-buffer-alist` and removes it when disabled
(`disbuf-pivot.el:352`, `disbuf-pivot.el:361`). The condition matches
every buffer an earlier
entry does not take and records the caller's ACTION in
`dp-action--action`, because `buffer-match-p` passes ACTION to the
condition while the action functions receive only the merged alist
(`disbuf-pivot.el:94`).

`dp-action--display` decides the target (`disbuf-pivot.el:333`):

1. A tab or frame named by the alist or ACTION is prompted for; the tab
   prompt handles both an existing and a new tab, and the frame prompt
   handles both an existing and a new frame.
2. An alist that names a place (`window`, `direction`, `side`, `slot`,
   `parent-frame`, or `child-frame-parameters`) is left to the caller.
3. Otherwise `disbuf-pivot-action-functions` runs in order.

The default functions reuse a window that displays the buffer, use the
selected window, then
`disbuf-pivot-action-split-or-ask` -- split when the split rule allows
it, otherwise ask with `ace-window`.

The `disbuf-pivot-action-select` and
`disbuf-pivot-other-window-prefix-select` options accept `t`, `auto`,
and `nil`. The `nil` case uses
`disbuf-pivot-window-utility-select-window-post-command`, which adds a
`post-command-hook` entry that selects the window and removes itself, as
`display-buffer` does for a nil `post-command-select-window`.

### The prefix commands

`disbuf-pivot-prefix-mode` remaps `same-window-prefix`,
`other-window-prefix`, `other-tab-prefix`, and `other-frame-prefix` to
the package commands. Each command installs an override for the next
command with `display-buffer-override-next-command`. When the selected
window cannot display a buffer, the commands use the most recently used
editing window of the frame, or of the parent frame when a child frame
is selected.

Tab and frame creation can itself display a buffer. The
`disbuf-pivot-other-tab-prefix--in-progress` and
`disbuf-pivot-other-frame-prefix--in-progress` variables keep that
display from prompting again; the nested display is left to the other
display rules.

### Dependency boundaries

The display package does not require `emacs-utils` or `column-popup`;
`emacs-utils` consumes the optional consult library. Keep that
direction. `consult` is optional and is required only by
`disbuf-pivot-tab-bar-consult.el`.

## Tests

Buttercup tests are under `test/`:

- `test/order-test.el` -- "ia display action ordering"
- `test/display-ask-test.el` -- "ia display action"
- `test/tab-frame-test.el` -- "ia tab and frame target"

The test files keep the `check` harness they had in `emacs-utils`. The
consult preview has no full preview test; compilation and checkdoc check
it. Update `CHANGELOG.md` under `## Unreleased` for a change a user of
the package should know.
