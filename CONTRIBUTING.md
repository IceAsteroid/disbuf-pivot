# Contributing

This is the developer guide for `disbuf-pivot`.  It covers the repository
layout, the commands, how to verify a change, and the dependency
boundaries.  The conventions are under `docs/`.

## The repository

`disbuf-pivot.el` is the package main file and carries the only
`Package-Requires`.  It holds the package's `display-buffer-alist`
entry, its options, the tab and frame prompts, and the mode.

`disbuf-pivot-window-utility.el` holds the window test, the split
options, the window prompt, the dispatch prompt, and the post-command
selection.

`disbuf-pivot-prefix.el` holds the prefix commands and the global minor
mode that remaps the built-in prefix commands.  The mode uses a keymap;
it does not advise `display-buffer`.

`disbuf-pivot-tab-bar.el` holds the tab candidates, history, tab
selection, and the plain tab reader.

`disbuf-pivot-tab-bar-consult.el` holds the optional consult reader and
the mode that installs it.

`test/` holds the Buttercup tests.  `README.md` describes use;
`CHANGELOG.md` records the incremental changes.  `Makefile`, `Eldev`,
and `.github/workflows/test.yml` hold the checks.

The internal dependency directions are:

```text
disbuf-pivot.el (feature disbuf-pivot)
├── disbuf-pivot-window-utility.el (dp-window-utility)
├── disbuf-pivot-tab-bar.el (dp-tab-bar)
└── ace-window, tab-bar

disbuf-pivot-prefix.el (dp-prefix)
├── disbuf-pivot.el
└── disbuf-pivot-window-utility.el

disbuf-pivot-tab-bar-consult.el (dp-tab-bar-consult, optional)
├── disbuf-pivot-tab-bar.el
└── consult
```

## Commands

```sh
make check           # byte-compile CHECK_FILES, then eldev test
make test            # eldev test only
make checkdoc        # checkdoc each CHECK_FILES entry
make check-consult   # compile and checkdoc the optional consult library
```

- Dependencies are found under `ELPA`; `make check` needs `ace-window`
  and `avy`; `make check-consult` needs `consult` too.
- `make check-consult` does not run tests.
- The test files are `order-test.el`, `display-ask-test.el`, and
  `tab-frame-test.el`.
- One test file: `eldev test -f order-test.el`.
- One spec:
  `eldev test -f order-test.el "ia display-buffer-alist entry ordering"`.
- CI runs `make check`, `make checkdoc`, and `make check-consult` on
  Emacs 31.1.

## Verifying work

Run `make check`, `make checkdoc`, and `make check-consult` for a code
change.  Report what was verified and what was not.

- Interactive prompts need a pty.  Reproduce with `emacs -Q` and a
  minimal file under `/tmp`.  Never load the user's init or desktop: it
  restores private buffers, and keystrokes can reach them.
- Cite the file and line for a mechanism you read.  Mark a statement
  you have not checked as unverified.
- The tests are under `test/`; the consult preview has no full preview
  test.

## Dependency boundaries

The display package does not require `emacs-utils` or `column-popup`;
`emacs-utils` consumes the optional consult library.  `consult` is
optional and only the consult library requires it.  The entry needs
`ace-window`; `avy` is required by `ace-window`.  `tab-bar-mode`
is needed for tab targets.

Keep that direction.  The display repository is separate from
`emacs-utils`; do not make one require the other.

## Documents

- `README.md` -- the user guide.
- `CHANGELOG.md` -- user-visible and internal changes.
- `docs/DOCUMENTATION_CONVENTION.md` -- terms, prose, and documentation.
- `docs/GIT_CONVENTION.md` -- commits and history.
- `docs/CHANGELOG_CONVENTION.md` -- changelog entries.
- `docs/DESIGN_RULESET.md` -- target behavior.
- `docs/DISPLAY_BUFFER_MATRIX.md` -- Emacs 31.1 action matrix
  (reference, not normative).
- `AGENTS.md` -- the coding-agent index.
