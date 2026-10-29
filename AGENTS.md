# Instructions for coding agents

This repository follows `TERM_AND_CONVENTION.md`.  Read it before
writing a change or the reply that describes it.

Check prose against the codification: is the word a Core term, is it in
Terms not used, and does Emacs have the word?  Code, identifiers and
shell commands are not prose.

## The repository

`disbuf-pivot.el` is the package main file and carries the only
`Package-Requires`.  It holds the display action, its options, the tab
and frame prompts, and the mode.

`disbuf-pivot-window-utility.el` holds the window test, the split
options, the prompt that reads a window, and the post-command selection.

`disbuf-pivot-prefix.el` holds the prefix commands and the global minor
mode that remaps the built-in prefix commands.  The mode uses a keymap;
it does not advise `display-buffer`.

`disbuf-pivot-tab-bar.el` holds the tab candidates, history, tab
selection, and the plain tab reader.

`disbuf-pivot-tab-bar-consult.el` holds the optional consult reader and
the mode that installs it.

The package is standalone.  It does not require `emacs-utils`;
`emacs-utils` consumes the optional consult library.  `consult` is
optional and only the consult library requires it.  The display action
needs `ace-window`; `avy` is required by `ace-window`.  `tab-bar-mode`
is needed for tab targets.

`test/` holds the Buttercup tests.  `README.md` describes use;
`CHANGELOG.md` records the incremental changes; `TERM_AND_CONVENTION.md`
is the term and commit authority.  `Makefile`, `Eldev`, and
`.github/workflows/test.yml` hold the checks.

## Verifying work

Run `make check`: it byte-compiles the files named by `CHECK_FILES` and
runs `eldev test`.  `make check-consult` compiles and checks the
optional consult library; it needs `consult`.  `make checkdoc` reports
the docstring findings.  The CI runs `make check`, `make checkdoc`, and
`make check-consult`.

- Dependencies are found under `ELPA`; `make check` needs `ace-window`
  and `avy`; `make check-consult` needs `consult` too.
- Interactive prompts need a pty.  Reproduce with `emacs -Q` and a
  minimal file under `/tmp`.  Never load the user's init or desktop: it
  restores private buffers, and keystrokes can reach them.
- Cite the file and line for a mechanism you read.  Mark a statement
  you have not checked as unverified.  Report what was verified and
  what was not.
- The tests are under `test/`; the consult preview has no full preview
  test.

## Documentation

- Use Emacs's terms and common technical terms directly.  Do not add
  parenthetical definitions of `window-dedicated-p`, `window-side`,
  `frame-parent`, `action list`, `ace-window`, `consult`, PGTK, Corfu,
  or Buttercup.
- Package terms are defined in `TERM_AND_CONVENTION.md`.  The README
  uses them; add an explanation only when the reader needs it to use
  the package.
- Do not use footnotes for term definitions.  The term file is the
  place for definitions; a footnote in the README separates the term
  from its use and renders differently across viewers.
- Docstrings wrap at 80 columns.  A `defvar` or `defcustom` docstring
  longer than 80 columns makes the byte-compiler warn; checkdoc reports
  the rest.
- The README is a user's guide: state the problem, the behavior, the
  commands, the requirements, and the checks.  Leave option defaults to
  the docstrings.
- A library that is not the package main file names an optional
  dependency in its Commentary and `README.md`; only the main file
  carries `Package-Requires`.

## Commits

This repository uses per-change commits; stage explicit paths, never a
directory.  Follow `TERM_AND_CONVENTION.md` for the message and the
atomic-commit rule.  Do not rewrite an existing commit.  The display
repository is separate from `emacs-utils`; do not make one require the
other.

- Subject type prefixes: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`.
- Wrap commit-message lines at about 72 columns.
- A fix labels `Symptom:`, `Root cause:` and `Fix:`; a feature labels
  `Add:`; a documentation-only change is `docs:` and can label `Doc:`.
- Update `CHANGELOG.md` for a change a user of the package should know.
- The user's uncommitted files are not yours.  Stage explicit paths and
  leave a file you were not asked to change alone.
