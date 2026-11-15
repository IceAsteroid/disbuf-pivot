# disbuf-pivot — Terms and documentation convention

This file is the authority for terms, prose, and documentation
conventions.  It applies to code, Commentary, docstrings, `README.md`,
`CHANGELOG.md`, and commit messages.  `docs/GIT_CONVENTION.md` is the
authority for commit structure; `docs/CHANGELOG_CONVENTION.md` for
changelog structure; `docs/DESIGN_RULESET.md` for intended behavior.  The
emacs-utils and column-popup files are models; they do not govern this
repository.

## Core terms

Emacs's terms and common technical terms are used as they are.  The
entries below are this package's terms.

- **pivot** — the point at which the package either respects the
  caller's intent or replaces that intent with the user's explicit
  choice.  The package name uses the word.
- **target**, **placement path** — a target is a frame, tab, or window
  that the caller's intent names or the user chooses through a prompt.
  A frame or tab target is a container; a window target is the window
  that displays the buffer.  The placement path is the sequence frame,
  then tab, then window; tab, then window; or window, ending at the
  window that displays the buffer.  A target is one step on the path.
- **intended choice**, **chosen window** — the intended choice is the
  target or dispatch action the package uses if the user accepts
  without choosing another; the dispatch prompt shows it with a key.
  An intended window is not a chosen window until the user accepts;
  when no target or action can run, the prompt has no intended choice.
  The chosen window is the window the user chooses through the package's
  prompt or dispatch action.  A window used silently by the default
  policy is not a chosen window.
- **dispatch prompt**, **dispatch action**, **dispatch action list** —
  the dispatch prompt is the transient menu the package shows at the
  pivot.  It draws the labels on every window in the selected tab or
  frame: a label for an eligible window takes one face and acts; a label
  for an ineligible window takes another face and states the condition.
  It shows the same labels in a separate group in the menu, with the
  same keys and faces.  It shows caller intent info, the intended
  choice, the dispatch action list, and a window-setting toggle for each
  window-setting entry.  It reads the keys for the window labels, the
  dispatch actions, and the toggles; the package does not call
  `aw-select`.  It computes the windows before it is shown and does not
  label its own window.  A dispatch action is a key the dispatch prompt
  runs instead of a window label; `aw-dispatch-alist` supplies the
  user's actions; the package supplies its own.  The dispatch action
  list is the grouped list of actions the prompt offers: the split
  actions from `aw-dispatch-alist`, the caller intent actions, and the
  Other actions the package offers, including the cancel key.
- **split action** — a dispatch action that splits a window and displays
  the buffer in the new window.
- **tab or frame action**, **child-frame action** — a tab or frame
  action is `display-buffer-in-tab`, `display-buffer-in-new-tab`,
  `display-buffer-pop-up-frame`, or `display-buffer-use-some-frame`.  A
  child-frame action is `display-buffer-in-child-frame`.
- **tab prompt**, **frame prompt** — the tab prompt reads a tab name;
  `disbuf-pivot-tab-bar-read-tab-name` implements it.
  `disbuf-pivot-tab-bar-read-function` can replace its reader, and the
  optional consult library supplies another reader.  The frame prompt
  reads a frame name from the live visible top-level frames, filtered by
  `frame-predicate`; `dp-action--frame` implements it.  An existing name
  selects the frame, a new name makes a new frame, and an empty name
  makes a new frame with the default name.
- **failure after the choice** — a failure after the user chooses a
  window, tab, frame, or dispatch action from a prompt: the chosen
  window is undisplayable, its frame or tab is gone, or the display
  function returns nil or errors.  The design rules list the responses.
- **abort**, **nil choice** — an abort ends the display instead of
  prompting again or returning nil, and does not run the later functions
  in the caller's ACTION.  C-g is the user's way to abort; `quit` is its
  mechanism; the leave-undisplayed outcome is not an abort.  A nil
  choice is the prompt returning nil without C-g; the action returns
  nil, and the later functions in Emacs's combined function list run.
  The dispatch prompt's cancel key makes a nil choice.  A nil choice is
  not an abort.
- **caller's ACTION**, **caller intent**, **caller intent info** — the
  caller's ACTION is the ACTION argument of the `display-buffer` call: a
  `(FUNCTIONS . ALIST)` pair.  Its first function is the caller's
  primary intent; its alist is part of the combined action alist.  An
  ACTION with no function is no preference; ACTION `t` is an
  other-window request.  The caller intent is what the ACTION asks for;
  the first function names a place, a tab or frame, a relative
  placement, a strategy, no display, or no preference.  A constraint or
  a window-setting entry is an entry the rule reads, not a class.  The
  caller intent info is the message that states what the ACTION asks for
  and the other entries in the combined action alist that the rule
  reads.  When an entry is not from the caller's ACTION, the message
  names the action that supplies it.  The dispatch prompt shows it.
- **caller constraint**, **selection entry**, **window-setting entry**,
  **window-setting toggle** — a caller constraint is an action-alist
  entry from the caller's ACTION that limits or orders the candidate
  windows; the design rules name the entries; `inhibit-switch-frame` and
  `allow-no-window` are not caller constraints.  A selection entry is an
  entry in an action alist that limits, orders, or chooses the candidate
  window, frame, tab, or placement, or the display outcome.  The package
  uses it during the prompt; it is not applied to the chosen window
  afterward.  A window-setting entry is an entry in an action alist that
  changes the chosen window itself: its dedication, parameters, or
  size.  The design rules name the entries; `body-function` is not a
  window-setting entry.  A window-setting toggle is a key the dispatch
  prompt shows for a window-setting entry.  It removes or restores every
  association of that entry's key in the combined action alist for the
  package's display call and for a run of the caller's function list
  from that prompt.  It does not change the caller's ACTION and does not
  affect later calls.
- **displayable window**, **undisplayable window** — a displayable
  window can display a buffer: it is live, is not a minibuffer window,
  is not dedicated to another buffer, and is not a side window.  An
  undisplayable window is not a displayable window: it is dead, is a
  minibuffer window, is dedicated to another buffer, or is a side
  window.  The design rules list the conditions.
- **cannot prompt**, **no prompt** — the package cannot prompt when it
  cannot read interactive input: the dispatch prompt, the tab prompt, or
  the frame prompt.  The design rules list the contexts.  No prompt
  means the package does not ask: the rule gives the window or
  placement, or the context is cannot prompt and the action returns nil.
  No prompt is the rules-table form; do not prompt is the imperative.
- **eligible window**, **ineligible window** — an eligible window is one
  the current prompt offers: it is a displayable window, and no rule
  excludes it from the prompt.  `inhibit-same-window` does not exclude
  the selected window from the prompt; the prompt offers it and binds
  the entry to nil when the user chooses it.  An ineligible window is
  one the current prompt does not offer: an undisplayable window, or a
  displayable window that a rule excludes from the prompt.  The dispatch
  prompt labels an ineligible window with a different face.
- **excluded buffer** — a buffer that matches
  `disbuf-pivot-exclude-conditions`; the package does not regulate it.
- **built-in prefix command**, **package prefix command** — a built-in
  prefix command is one of Emacs's `same-window-prefix`,
  `other-window-prefix`, `other-tab-prefix`, and `other-frame-prefix`;
  it sets `display-buffer-overriding-action` for the next command.  A
  package prefix command is one of the package's
  `disbuf-pivot-same-window-prefix`,
  `disbuf-pivot-other-window-prefix`,
  `disbuf-pivot-other-tab-prefix`, and
  `disbuf-pivot-other-frame-prefix`; `disbuf-pivot-prefix-mode`
  remaps the built-in prefix commands to these commands.

## Emacs terms used by the design

- **combined action alist** — the action alist `display-buffer` builds
  by combining, in order, the alists from
  `display-buffer-overriding-action`, the matching
  `display-buffer-alist` entry, the special action, the caller's ACTION,
  the extra action (the old-style ACTION and the FRAME argument),
  `display-buffer-base-action`, and `display-buffer-fallback-action`.
  The first association of a key wins.
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
  **undisplayable window** or cannot display, and name the condition.
- failed interactive display — name the failure: the chosen window is
  undisplayable, its frame or tab is gone, or the display function
  errors.
- display action, for the package's entry — say **the package's
  `display-buffer-alist` entry**, or name the condition and action
  function.
- merged alist — use **combined action alist**.
- flow, for the frame/tab/window sequence — use **placement path**.
- driver — say that the package reads the keys, or name the function
  that reads them; a transient prefix command returns before the user
  chooses.
- placement entry — say **the entry that names a place**, or name the
  entry.
- fallback line — say the key for the intended choice, or name the
  cancel key.
- window prompt — use **dispatch prompt**.  The current source and
  README still have a separate window prompt; the design uses the
  dispatch prompt.
- dispatch hint — use the **dispatch action list**.  The current source
  and README still show the hint; the design shows the list in the
  dispatch prompt.
- caller action — say the action from the caller's ACTION, or name the
  action function.
- the opt-out, window-settings opt-out — use **window-setting toggle**,
  or name the toggle.
- tab reader — use **tab prompt**; name
  `disbuf-pivot-tab-bar-read-tab-name` or the replaceable reader when
  the implementation is meant.  The current source and README still use
  the term.
- frame reader — use **frame prompt**; the frame prompt is a
  `completing-read` prompt, not a replaceable reader.
- split rule — name `disbuf-pivot-window-utility-split-p` and its
  options; the core does not consult them.  The current source and
  README still use the term.
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
