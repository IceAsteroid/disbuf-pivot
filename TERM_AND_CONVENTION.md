# disbuf-pivot — Terms and conventions

This file is the authority for this repository.  It binds code,
Commentary, docstrings, `README.md`, `CHANGELOG.md`, and commit
messages.  The emacs-utils and column-popup files are models; they do
not govern this repository.

## Core terms

Emacs's terms and common technical terms are used as they are.  The
entries below are this package's terms.

- **pivot** — the window, tab, or frame where a buffer is displayed;
  the package's name for it.  The package name uses the word.
- **display action** — the entry `disbuf-pivot-action-mode` installs in
  `display-buffer-alist`; `display-buffer` calls its function for a
  buffer no earlier entry takes.
- **window prompt** — the prompt that reads a window, implemented by
  `disbuf-pivot-window-utility-choose-tab-window` and
  `disbuf-pivot-window-utility-choose-display-window`.
- **split rule** — `disbuf-pivot-window-utility-split-p`, which
  compares the number of windows with
  `disbuf-pivot-window-utility-split-maximum` and its exclusion
  options.
- **tab reader** — `disbuf-pivot-tab-bar-read-tab-name`, the function
  that reads a tab name; the optional consult library supplies another
  reader.

## Terms not used

These forms are avoided in Commentary, docstrings, `README.md`,
`CHANGELOG.md`, and commit messages.  Each entry gives the phrasing to
use instead.  A shell command, an identifier, or a code fragment is not
prose.

- utility popup — use **dedicated window**, **side window**, **child
  frame**, or **window that cannot display a buffer**, whichever is
  meant.
- workspace — use **editing window**, or name the function that returns
  it.
- frame title, when the frame's `name` parameter is meant — use **frame
  name**.
- popup as a noun — use **pop-up window** for a window made by
  `display-buffer-pop-up-window` or `pop-up-windows`, or name the
  condition.
- adopt / adopted — describe the action: use, select, or apply the
  thing, whichever is meant.
- session — say the call or the command, or "while the minibuffer is
  active," whichever is meant.
- echo — "echo area" is Emacs's term for the area where messages
  appear; use it rather than "the echo."  Identifiers keep the `echo`
  prefix, as Emacs does (`echo-keystrokes`).
- task context — delete the phrase, or say "the minibuffer."
- claim / claimed — say which thing does what: a window displays a
  buffer, a function returns a value, a mode installs a hook.
- stays / stayed — "remains / remained."
- summon / summoned — "display / displayed" for a buffer, "make / made"
  for a window, frame, or tab.
- spawn / spawned / spawning — "make / made" for a window, frame, or
  tab; "display / displayed" for a buffer.
- open a buffer / create a buffer — say "display a buffer in a window."
  A function that creates a buffer names `get-buffer-create`; the
  display rule does not make one.
- question, for the prompt of `completing-read` — say "prompt," or name
  the function that reads the name.

## Conventions

- Use Emacs's term before a package term.  A package term is acceptable
  when Emacs has no concise word and the term is defined above.
- Never introduce a preferred wording or term without asking first.
  Propose it with the reason; the established word wins unless the
  maintainer agrees.
- Term explanations belong in this file.  The README uses the terms; it
  adds an explanation only when the reader needs it to use the package.
  Do not add parenthetical definitions of Emacs terms or common
  technical terms.
- Do not use footnotes for term definitions.  They separate the term
  from its use, and they render differently across viewers.
- Present tense for verbs.  A title describes the current behavior; a
  body paragraph uses the labels `Symptom:`, `Root cause:`, `Fix:`,
  `Add:`, or `Doc:` as its change needs.
- One atomic commit per logical change: the code and the documentation
  of that change in the same commit, so a checkout of any commit shows
  the code and the documentation that describe it.  A change that
  touches only documentation is its own commit; unrelated changes are
  separate commits even when they touch one file.
- Subject type prefixes: `feat:` for a new behavior or option, `fix:`
  for a correction, `refactor:` for a change that keeps behavior,
  `docs:` for documentation only, and `test:` for a change that only
  adds or changes tests.
- Wrap commit-message lines at about 72 columns.  Wrap docstrings at 80
  columns.  A `defvar` or `defcustom` docstring longer than 80 columns
  makes the byte-compiler warn; checkdoc reports the rest.
- Do not rewrite an existing commit.  A message that violates a rule
  written after it keeps its form.
- Update `CHANGELOG.md` at the top of `## Unreleased` for a change a
  user of the package should know.  The entry names the change, not a
  commit hash.
- A term must be added to Core terms with the maintainer's agreement
  before it is used.  A term that is dropped moves to Terms not used
  with its replacement.
- The display package does not require `emacs-utils` or `column-popup`;
  `emacs-utils` consumes the optional consult library.
- Only the package main file carries `Package-Requires`.  A library
  that is not the main file names an optional dependency in its
  Commentary and `README.md`.
- Quote a symbol or a code fragment with a grave accent on both sides
  in Markdown and commit messages; in Emacs Lisp source use a grave
  accent before and an apostrophe after.
- Verify with `make check`, `make check-consult`, and `make checkdoc`.
  Interactive prompts need a pty; cite the file and line for a
  mechanism you read, and mark a statement you have not checked as
  unverified.
