# disbuf-pivot — Terms and documentation convention

This file is the authority for terms, prose, and documentation
conventions.  It applies to code, Commentary, docstrings, `README.md`,
`CHANGELOG.md`, and commit messages.  `docs/GIT_CONVENTION.md` is the
authority for commit structure; `docs/CHANGELOG_CONVENTION.md` for
changelog structure; `docs/DESIGN_RULESET.md` for target behavior.  The
emacs-utils and column-popup files are models; they do not govern this
repository.

## Core terms

Emacs's terms and common technical terms are used as they are.  The
entries below are this package's terms.

- **pivot** — the window, tab, or frame where a buffer is displayed;
  the package's name for it.  The package name uses the word.
- **window prompt** — the prompt that calls `aw-select` to label the
  eligible windows and reads a label.  The dispatch hint is shown in
  the echo area; its mode-line copy is optional; `?` shows the dispatch
  action list in the echo area.
- **dispatch prompt** — the echo-area prompt in
  `disbuf-pivot-window-utility-choose-sole-window` that shows the
  dispatch action list and reads one key; it labels no windows.
- **dispatch action** — a key a prompt runs instead of reading a window
  label.  `aw-dispatch-alist` supplies the user's actions; the package
  supplies its own.
- **dispatch action list** — the grouped list of actions a prompt
  offers: the split actions from `aw-dispatch-alist`, the caller
  actions, and the other actions the package offers.  The window prompt
  shows it with `?`; the one-window dispatch prompt shows it directly.
- **dispatch hint** — the one-line string `Display buffer in window
  (? for actions)` or `Choose another window (? for actions)`.  It
  tells the user that `?` shows the dispatch action list.
- **split rule** — `disbuf-pivot-window-utility-split-p`, which
  compares the number of windows with
  `disbuf-pivot-window-utility-split-maximum` and its exclusion
  options.
- **split action** — a dispatch action that splits a window and displays
  the buffer in the new window.
- **tab or frame action** — `display-buffer-in-tab`,
  `display-buffer-in-new-tab`, `display-buffer-pop-up-frame`, or
  `display-buffer-use-some-frame`.
- **child-frame action** — `display-buffer-in-child-frame`.
- **tab reader** — `disbuf-pivot-tab-bar-read-tab-name`, the function
  that reads a tab name; the optional consult library supplies another
  reader.
- **chosen window** — the window the user chooses through the package's
  prompt or dispatch action.  A window used silently by the default
  policy is not a chosen window.
- **caller intent** — what the caller's ACTION asks for; the design
  rules classify it by what it names: a place, a strategy, a
  constraint, or no preference.
- **caller intent info** — the message that states what the caller
  asked for and, when relevant, which caller constraint applies.  The
  package shows it in the echo area.
- **caller constraint** — an action-alist entry from the caller that
  limits the candidate windows; the design rules name the entries.
- **undisplayable window**, **cannot display** — a window that is not a
  **displayable window**: it is dead, is a minibuffer window, is
  dedicated to another buffer, or is a side window.  The design rules
  list the conditions.
- **cannot prompt** — the package cannot read interactive input: the
  window prompt, the dispatch prompt, the tab reader, or the frame
  prompt.  The design rules list the contexts.
- **no prompt**, **do not prompt** — the package does not ask.  The
  rule gives the window or placement, or the context is **cannot
  prompt** and the action returns nil.  **No prompt** is the rules-table
  form; **do not prompt** is the imperative.
- **displayable window**, **can display** — a window that can display a
  buffer: it is live, is not a minibuffer window, is not dedicated to
  another buffer, and is not a side window.
- **eligible window** — a window the current prompt offers: it is a
  displayable window, and the current intent does not exclude it.
- **excluded buffer** — a buffer that matches
  `disbuf-pivot-exclude-conditions`; the package does not regulate it.
- **built-in prefix command** — one of Emacs's `same-window-prefix`,
  `other-window-prefix`, `other-tab-prefix`, and
  `other-frame-prefix`; a command that sets
  `display-buffer-overriding-action` for the next command.
- **package prefix command** — one of the package's
  `disbuf-pivot-same-window-prefix`,
  `disbuf-pivot-other-window-prefix`,
  `disbuf-pivot-other-tab-prefix`, and
  `disbuf-pivot-other-frame-prefix`; `disbuf-pivot-prefix-mode`
  remaps the built-in prefix commands to these commands.

## Emacs terms used by the design

- **top-level frame** — an Emacs frame whose `parent-frame` parameter
  is nil.  On a graphical display it is a separate desktop window
  managed by the graphical environment's window manager; on a text
  terminal it occupies the terminal.  A frame created with `make-frame`
  while another frame is selected is still top-level unless its
  `parent-frame` parameter is non-nil.
- **child frame** — an Emacs frame whose `parent-frame` parameter is
  non-nil.  It is displayed within the parent frame's area and is not a
  separate desktop window.

## Terms not used

These forms are avoided in Commentary, docstrings, `README.md`,
`CHANGELOG.md`, and commit messages.  Each entry gives the phrasing to
use instead.  A shell command, an identifier, or a code fragment is not
prose.

- utility popup — use **dedicated window**, **side window**, **child
  frame**, or **undisplayable window**, whichever is meant.
- physical / physically, for an undisplayable window — say
  **undisplayable window** or **cannot display**, and name the
  condition.
- failed interactive display — name the failure: the chosen window is
  undisplayable, its frame or tab is gone, or the display function
  errors.
- display action, for the package's entry — say **the package's
  `display-buffer-alist` entry**, or name the condition and action
  function.
- no-prompt — use **no prompt**.
- workspace — use **window**, or name the function that returns it.
- editing window — say **displayable window**, or "the most recently
  used displayable window."
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
- Present tense for verbs.
- Commit messages follow `docs/GIT_CONVENTION.md`; changelog entries
  follow `docs/CHANGELOG_CONVENTION.md`.  Both use the terms in this
  file.
- Wrap docstrings at 80 columns.  A `defvar` or `defcustom` docstring
  longer than 80 columns makes the byte-compiler warn; checkdoc reports
  the rest.
- A term must be added to Core terms with the maintainer's agreement
  before it is used.  A term that is dropped moves to Terms not used
  with its replacement.
- Only the package main file carries `Package-Requires`.  A library
  that is not the main file names an optional dependency in its
  Commentary and `README.md`.
- Quote a symbol or a code fragment with a grave accent on both sides
  in Markdown and commit messages; in Emacs Lisp source use a grave
  accent before and an apostrophe after.
- Verification and dependency rules are in `CONTRIBUTING.md`.
