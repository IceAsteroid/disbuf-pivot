# Contributing

This is the developer guide for `disbuf-pivot`.  It covers the
repository layout, the commands, verification, dependency boundaries,
commits and history, and changelog entries.  Terms, prose, and
documentation rules are in `docs/DOCUMENTATION_CONVENTION.md`; intended
behavior is in `docs/DESIGN_RULESET.md`.

## The repository

`disbuf-pivot.el` is the package main file and carries the only
`Package-Requires`.  It holds the package's `display-buffer-alist`
entry, its options, the tab and frame prompts, and the mode.

`disbuf-pivot-window-utility.el` holds the window predicates, the
cannot-prompt guards, the window-labeling overlays and split
primitives, the synchronous dispatch prompt menu, and the post-command
selection.

`disbuf-pivot-prefix.el` holds the prefix commands and the global minor
mode that remaps the built-in prefix commands.  The mode uses a keymap;
it does not advise `display-buffer`.

`disbuf-pivot-tab-bar.el` holds the tab candidates, history, tab
selection, and the plain tab reader.

`disbuf-pivot-tab-bar-consult.el` holds the consult tab reader and the
mode that installs it.

`test/` holds the Buttercup tests.  `README.md` describes use;
`CHANGELOG.md` records the incremental changes.  `Makefile`, `Eldev`,
and `.github/workflows/test.yml` hold the checks.

The internal dependency directions are:

```text
disbuf-pivot.el (feature disbuf-pivot)
├── disbuf-pivot-window-utility.el (dp-window-utility)
├── disbuf-pivot-tab-bar.el (dp-tab-bar)
└── tab-bar

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

- Dependencies are found under `ELPA`; `make check` currently needs
  `ace-window` and `avy`, and `make check-consult` needs `consult` too.
- `eldev` must be on `PATH`; the checks call it directly.
- `make check-consult` does not run tests.
- The test files are `core-test.el`, `dispatch-prompt-test.el`,
  `intent-rules-test.el`, `order-test.el`, `display-ask-test.el`, and
  `tab-frame-test.el`.
- One test file: `eldev test -f order-test.el`.
- One spec:
  `eldev test -f order-test.el "disbuf-pivot display-buffer-alist entry ordering"`.
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
optional and only the consult library requires it.  The package's own
window-labeling and split facility in `disbuf-pivot-window-utility.el`
has no runtime reference to `ace-window`; `Package-Requires`,
`Makefile`, and CI still carry `ace-window` (`avy` is required by
`ace-window`) until the dependency cleanup milestone removes them.
`tab-bar-mode` is needed for tab targets.

Keep that direction.  The display repository is separate from
`emacs-utils`; do not make one require the other.

## Commits and history

Commit messages use the terms in `docs/DOCUMENTATION_CONVENTION.md`.

### Atomic commits

- One atomic commit per logical change: the code and the documentation
  of that change in the same commit, so a checkout of any commit shows
  the code and the documentation that describe it.
- A change that touches only documentation is its own commit; unrelated
  changes are separate commits even when they touch one file.
- Stage explicit paths, never a directory.  The user's uncommitted files
  are not yours; leave a file you were not asked to change alone.

### Commit messages

- Wrap commit-message lines at about 72 columns.
- A title describes the current behavior; a body paragraph labels the
  change: a fix uses `Symptom:`, `Root cause:`, and `Fix:`; a feature
  uses `Add:`; a documentation-only change is `docs:` and can label
  `Doc:`.
- Subject type prefixes:
  - `feat:` for a new behavior or option.
  - `fix:` for a correction.
  - `refactor:` for a change that keeps behavior.
  - `docs:` for documentation only.
  - `test:` for a change that only adds or changes tests.
  - `build:` for the build system or dependencies.
  - `ci:` for continuous integration.
  - `perf:` for a performance change that keeps behavior.
  - `style:` for formatting or whitespace only.
  - `chore:` for routine maintenance.
  - `revert:` for a revert of an earlier commit.
- Do not rewrite an existing commit.  A message that violates a rule
  written after it keeps its form.
- An assistant-authored commit ends with a `Co-Authored-By:` trailer
  naming the assistant.

## Changelog

`CHANGELOG.md` entries use the terms in
`docs/DOCUMENTATION_CONVENTION.md`.

- Update `CHANGELOG.md` at the top of `## Unreleased` for a
  user-visible or internal change.
- Put user-visible entries first under `### User-visible Changes`,
  internal entries last under `### Internal Changes`, and omit an empty
  section.
- User-visible entries use `Add:`, `Fix:`, or `Doc:` as the label.
- The entry names the change, not a commit hash.
- An internal entry may use the subject type name as its label
  (`Refactor:`, `Build:`, `CI:`, `Test:`, `Docs:`); use `Internal:` when
  one type does not fit.
- A pure refactor with no observable effect may be omitted or
  summarized under `Internal Changes`.
- When a change affects both audiences, state the user-visible effect
  in the user section; do not repeat it in the internal section.

## Documents

- `README.md` -- the user guide.
- `CHANGELOG.md` -- user-visible and internal changes.
- `CONTRIBUTING.md` -- commands, verification, dependencies, commits,
  and changelog conventions.
- `docs/DOCUMENTATION_CONVENTION.md` -- terms, prose, and documentation
  conventions.
- `docs/DESIGN_RULESET.md` -- intended behavior.
- `docs/DISPLAY_BUFFER_MATRIX.md` -- Emacs 31.1 action matrix
  (reference, not normative).
- `AGENTS.md` -- the coding-agent index.
