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

- **pivot**, **outside the pivot** — the pivot is the point at which
  the package either respects the caller's intent or replaces that
  intent with the user's explicit choice.  A tab prompt is outside the
  pivot when neither the package's `display-buffer-alist` entry nor a
  package prefix command shows it.  The package name uses the word.
- **target**, **placement path** — a target is a frame, tab, or window
  that the caller's intent names or the user chooses through a prompt.
  A frame or tab target is a container; a window target is the window
  that displays the buffer.  The placement path is the sequence frame,
  then tab, then window; tab, then window; or window, ending at the
  window that displays the buffer.  A target is one step on the path.
- **dispatch prompt default**, **tab prompt default**, **frame prompt
  default**, **chosen window** — the dispatch prompt default is the
  target or dispatch action the package uses if the user accepts
  without choosing another; the dispatch prompt menu shows it with a
  key.
  Accepting it means pressing the key the prompt shows for it instead
  of choosing another window label, another dispatch action, or the
  cancel key.  The key is the window label's key when the dispatch
  prompt default is a window, or the dispatch action's key when it is
  an action.  It is not the caller's intent; the caller intent is what
  the ACTION asks for.  When no target or action can run, the dispatch
  prompt has no default.
  The tab prompt default is the preselected tab, when the tab prompt
  preselects one; in `display-buffer-in-tab` it is the tab the caller's
  function would select.  The frame prompt default is the frame the
  frame prompt uses if the user accepts without choosing another: the
  preselected existing frame, or a new frame with the default name.
  Accepting the tab or frame prompt default means completing the prompt
  with the preselection or the default name instead of entering another
  name.  A prompt default is not chosen until the user accepts.  The
  chosen window is the window the user chooses through the package's
  prompt or dispatch action.  A window used silently by the default
  policy is not a chosen window.
- **dispatch prompt**, **dispatch action**, **dispatch action list** —
  the dispatch prompt is the package's synchronous interaction at the
  pivot.  It has two parts: the window labels drawn on the windows and
  the dispatch prompt menu.  It does not return to `display-buffer`
  until the user chooses.  It draws the labels on every window in the
  window label scope: a label for an eligible window takes one face and
  acts; a label for an ineligible window takes another face and
  states why it is ineligible.  A dispatch action is a key the dispatch
  prompt menu runs instead of a window label; `aw-dispatch-alist`
  supplies the user's split actions; the package supplies its own.  The
  dispatch action list is the grouped list of actions the dispatch
  prompt menu offers: the split actions from `aw-dispatch-alist`, the
  caller intent actions, and the Other actions the package offers,
  including the cancel key.
- **window label** — a key the dispatch prompt draws on a window; the
  same key appears in the Windows group, with the same face; the face
  states whether the window is eligible.  A window label is not a menu
  item.
- **window label scope** — the windows whose labels the dispatch prompt
  draws: the selected tab's windows when `tab-bar-mode` is active,
  otherwise the selected frame's windows.  The dispatch prompt menu
  window is not in the scope.
- **dispatch prompt key** — a key the dispatch prompt reads: a window
  label, a dispatch action, a window-setting toggle, the
  window-settings group toggle, or the cancel key.  The term names the
  key only; the specific term names its behavior.
- **dispatch prompt menu** — the menu part of the dispatch prompt,
  shown in the dispatch prompt menu window.  It is not a transient menu:
  the action function reads its keys and does not return to
  `display-buffer` until the user chooses.  The package computes the
  windows before the dispatch prompt menu is shown.  It does not label
  the dispatch prompt menu window.  It holds its header and its menu
  groups.  It shows the dispatch action list, a window-setting toggle
  for each window-setting entry present in the combined action alist,
  and the window-settings group toggle when at least one window-setting
  entry is present.  It reads the keys for the window labels, the
  dispatch actions, and the toggles.  The package does not call
  `aw-select` or a transient prefix command.
- **dispatch prompt menu window** — the side window that shows the
  dispatch prompt menu; the prompt does not label it.
- **dispatch prompt menu header** — the part of the dispatch prompt menu
  above the groups; it holds the caller intent info, which states the
  caller's request and the window facts, and the dispatch prompt
  default, which gives the target or action the prompt uses if the user
  accepts.
- **dispatch prompt menu group**, **Windows group**,
  **dispatch action group**, **window-settings group** — a dispatch
  prompt menu group is a visually separated group in the dispatch
  prompt menu.  The Windows group repeats the window labels.  The
  dispatch action group holds the dispatch action list; its label is
  "Dispatch actions".  The window-settings group holds the
  window-setting toggles and the window-settings group toggle; its
  label is "Window settings".  The Split, Caller intent, and Other
  groups of the dispatch action list are subgroups.
- **split action** — a dispatch action that splits a window and displays
  the buffer in the new window.
- **tab or frame action**, **child-frame action** — a tab or frame
  action is `display-buffer-in-tab`, `display-buffer-in-new-tab`,
  `display-buffer-pop-up-frame`, or `display-buffer-use-some-frame`.  A
  child-frame action is `display-buffer-in-child-frame`.
- **tab prompt**, **frame prompt** — the tab prompt reads a tab name;
  `disbuf-pivot-tab-bar-read-tab-name` implements it.
  `disbuf-pivot-tab-bar-read-function` can replace the plain tab
  reader, and the optional consult library supplies the consult tab
  reader.  Choosing an existing name selects the tab; a new name makes
  a new tab.  The frame prompt reads a frame name from the live visible
  top-level frames, filtered by `frame-predicate`; `dp-action--frame`
  implements it.  An existing name selects the frame, a new name makes
  a new frame, and an empty name makes a new frame with the default
  name.
- **plain tab reader**, **consult tab reader** — the plain tab reader is
  the tab prompt's built-in reader:
  `disbuf-pivot-tab-bar-read-tab-name` uses `completing-read` when
  `disbuf-pivot-tab-bar-read-function` is nil.  The consult tab reader
  is the optional reader in `disbuf-pivot-tab-bar-consult.el`;
  `disbuf-pivot-tab-bar-consult-mode` installs it in
  `disbuf-pivot-tab-bar-read-function`, and it uses `consult` and
  supplies previews.
- **tab prompt scope** — the frames whose tabs the tab prompt offers:
  nil for the selected frame, `t` for all existing frames, `visible`
  for the visible frames, `0` for all frames on the current terminal,
  or a frame, for that frame alone.  The `reusable-frames` entry of
  `display-buffer-in-tab` uses nil for no reusable search, so the nil
  meanings differ.
- **tab candidate annotation**, **tab annotation column** — the tab
  candidate annotation is the text the tab prompt appends to a
  candidate's name.  A tab annotation column is one field in that text:
  the state, the frame, the window count, the group, or the buffer.  The
  state is a tab index or a tab history candidate.  The package supplies
  the annotation, not Marginalia.
- **tab history candidate** — a tab prompt candidate from the tab
  history whose name matches no existing tab the prompt offers: no tab
  in the tab prompt scope and no added reusable tab.  The same name can
  be a tab history candidate in one prompt and a tab candidate in
  another, so the state is relative to the prompt.  The prompt marks
  such a candidate `(closed)`; the marker is relative to the tab prompt
  scope, which the prompt string states when it is not the selected
  frame.
- **failure after the choice** — a failure after the user chooses a
  window, tab, frame, or dispatch action from a prompt: the chosen
  window is undisplayable, its frame or tab is gone, or the action
  function returns nil or errors.  The design rules list the responses.
- **abort**, **nil choice** — an abort ends the display instead of
  prompting again or returning nil, and does not run the later
  functions in the caller's function list.  C-g is the user's way to
  abort; `quit` is its mechanism; the leave-undisplayed outcome is not
  an abort.  A nil choice is the prompt returning nil without C-g; the
  action returns nil, and the later functions in Emacs's combined
  function list run.  The dispatch prompt menu's cancel key makes a nil
  choice.  A nil choice is not an abort.
- **caller**, **caller's ACTION**, **caller's function list**,
  **caller's action function**, **caller's fallback chain**,
  **caller intent**, **caller intent info** — the caller is the code
  that calls `display-buffer`; do not use the word for code that shows
  the tab prompt.  The caller's ACTION
  is the ACTION argument of the `display-buffer` call: a
  `(FUNCTIONS . ALIST)` pair.  Its first function is the caller's
  primary intent; its FUNCTIONS are the caller's function list, one
  function or a list, and are included in the combined function list;
  each function in the caller's function list is a caller's action
  function; its ALIST is part of the combined action alist.  The later
  functions in the caller's function list form the caller's fallback
  chain; each is a caller fallback.  An ACTION with no function is no
  preference; ACTION `t` is an other-window request.
  The caller intent is what the ACTION asks for; the first function
  names a place, a tab or frame, a relative placement, a strategy, no
  display, or no preference.  A constraint or a window-setting entry is
  an action alist entry the rule reads, not an intent class.  The caller intent
  info is the one-line summary in the dispatch prompt menu header.  The
  primary intent is the placement the caller's first function names.  An
  effect is a user-facing phrase for a consequence other than the
  primary intent's placement: a window setting or constraint from an
  action alist entry, a display outcome of the primary intent, or a
  fallback's placement.  It is not a raw action function or action
  alist entry.  A window fact is whether the selected window can
  display the buffer or which windows display the buffer; it is named
  when it affects the choice or the chosen window.  It is not the
  dispatch prompt default's target eligibility; when the default is a
  window, the window label for that target states that eligibility.
  The info names the primary intent, the effects of the primary intent
  and of the caller's action alist entries, the window facts, the
  caller's fallback chain, and the entries from other actions with
  their source labels.  It names the entries by their effects and
  sources, not as raw entries; the window-settings group shows when each
  window-setting entry applies: "new windows only", "new frame", or
  "any chosen window".
  The caller intent info uses a source label when an entry is not from
  the caller's ACTION.  The info does not name controls,
  entries the rule does not read, or the functions in the combined
  function list that come from sources other than the caller's ACTION.
  It introduces each later function in the caller's fallback chain with
  `else` and names it by its effect; a function the package does not
  cover is named by its symbol.  `body-function` is not named.
- **source label** — the label after a semicolon that names the action
  supplying an entry that is not from the caller's ACTION:
  `display-buffer-base-action` as "base action",
  `display-buffer-overriding-action` as "overriding action", and
  `display-buffer-fallback-action` as "fallback action"; the special
  action and the extra action are named as they are.  Use the full
  variable names everywhere else.
- **intent class** — the classification of the caller's ACTION by its
  first function: names a place, names a tab or frame, names a relative
  placement, names a strategy, no display, or no preference.  A caller's
  ACTION has one intent class: the first function names it; an ACTION
  with no function is no preference; ACTION `t` is the special
  other-window request, not an intent class.  Later functions in the
  caller's function list are fallbacks, and an action alist entry does
  not change the intent class.
- **caller constraint**, **selection entry**, **window-setting entry**,
  **window-setting toggle**, **window-settings group toggle** — an
  entry in these terms is an action alist entry, never a key in the
  dispatch prompt.  A caller constraint is an action alist entry from
  the caller's ACTION that limits or orders the candidate windows; the
  design rules name the entries; `inhibit-switch-frame` and
  `allow-no-window` are not caller constraints.  A selection entry is an
  action alist entry that limits, orders, or chooses the candidate
  window, frame, tab, or placement, or the display outcome.  The package
  uses it during the prompt; it is not applied to the chosen window
  afterward.  A window-setting entry is an action alist entry that
  changes the chosen window itself: its dedication, parameters, or
  size.  The design rules name the entries; `body-function` is not a
  window-setting entry.  A window-setting toggle is a key the dispatch
  prompt menu shows for a window-setting entry present in the combined
  action alist.  It removes or restores every association of that
  entry's action alist key in the combined action alist for the
  package's display call and for a run of the caller's function list
  from that prompt.  It does not change the caller's ACTION and does not
  affect later calls.  A window-setting toggle is on while its entry's
  action alist key remains in the combined action alist; it is off while
  the key is removed.  The window-settings group toggle is on, off, or
  mixed.  A window-settings group toggle is a key the dispatch prompt
  menu shows when at least one window-setting entry is present; it
  removes every window-setting entry or restores all of them, and keeps
  the prompt open.
- **displayable window**, **undisplayable window** — a displayable
  window can display a buffer: it is live, is not a minibuffer window,
  is not dedicated to another buffer, and is not a side window.  An
  undisplayable window is not a displayable window: it is dead, is a
  minibuffer window, is dedicated to another buffer, or is a side
  window.  The design rules list the eligibility conditions.
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

- **action alist entry** — an association in an action alist.  A
  `display-buffer-alist` element is not an action alist entry.
- **action function** — a function that accepts the buffer and an
  action alist, tries to display the buffer, and returns the window or
  nil; `display-buffer` calls it.  Examples are
  `display-buffer-same-window`, `display-buffer-reuse-window`, and
  `display-buffer-pop-up-frame`.  A tab or frame action is an action
  function; a dispatch action is not.
- **`display-buffer-alist` entry**, **display action**, **action alist** —
  a `display-buffer-alist` entry is an element of `display-buffer-alist`
  of the form `(CONDITION . ACTION)`.  CONDITION is a
  `buffer-match-p` condition; ACTION is a display action.  A display
  action is a cons cell `(FUNCTIONS . ALIST)`: FUNCTIONS is an action
  function, a list of action functions, or nil (the empty list), and
  ALIST is an action alist, an association list of action alist
  entries.  The caller's ACTION uses this form except for `t` and nil.
- **combined action alist**, **combined function list** — the two
  products of the same combination.  The combined action alist is the
  action alist `display-buffer` builds by combining, in order, the
  alists from `display-buffer-overriding-action`, the matching
  `display-buffer-alist` entry, the special action, the caller's ACTION,
  the extra action (the old-style ACTION and the FRAME argument),
  `display-buffer-base-action`, and `display-buffer-fallback-action`;
  the first association of a key wins.  The combined function list is
  the list of action functions built from the function lists of the
  same sources; `display-buffer` calls them in turn, passing each the
  combined action alist, until one returns non-nil, and does not remove
  duplicates.  The list is not an action alist.
- **top-level frame** — an Emacs frame whose `parent-frame` parameter
  is nil.  On a graphical display it is a separate desktop window
  managed by the graphical environment's window manager; on a text
  terminal it occupies the terminal.  A frame created with `make-frame`
  while another frame is selected is still top-level unless its
  `parent-frame` parameter is non-nil.
- **child frame** — an Emacs frame whose `parent-frame` parameter is
  non-nil.  It is displayed within the parent frame's area and is not a
  separate desktop window.
- **reusable tab** — a tab in one of the frames named by a non-nil
  `reusable-frames` entry that already displays the buffer.  A tab or
  frame action finds it with `tab-bar-get-buffer-tab`; the tab prompt
  offers it as a candidate, and choosing it selects its frame and the
  tab.  The dispatch prompt for its window may still run.
  `display-buffer-in-tab` uses the phrase.
- **transient menu** — the menu a transient prefix command shows; its
  keys are bound to transient suffix commands.
- **transient prefix command** — the command that shows a transient
  menu.  It sets up the menu and returns; later commands read the
  menu's keys.  Use the qualified term; a bare "prefix command" is a
  built-in prefix command or a package prefix command.
- **transient suffix command** — a command bound to a key in a
  transient menu.
- **transient stay suffix** — a transient suffix command that keeps the
  menu open.
- **transient exit suffix** — a transient suffix command that closes the
  menu and runs its function.

## Terms not used

These forms are avoided in Commentary, docstrings, `README.md`,
`CHANGELOG.md`, and commit messages.  Each entry gives the phrasing to
use instead.  A shell command, an identifier, or a code fragment is not
prose.

- dispatch prompt's menu — use **dispatch prompt menu**.
- menu item, menu entry, entry for a key in the dispatch prompt menu —
  use **window label**, **dispatch action**, or **window-setting
  toggle**; a window label is not a menu item, and an entry without a
  qualifier is an action alist entry.
- menu group — use **dispatch prompt menu group**.
- namespace, for a key class — name the specific dispatch prompt key:
  window labels, dispatch actions, or window-setting toggles.
- utility popup — use **dedicated window**, **side window**, **child
  frame**, or **undisplayable window**, whichever is meant.
- physical / physically, for an undisplayable window — say
  **undisplayable window** or cannot display, and name the condition.
- failed interactive display — name the failure: the chosen window is
  undisplayable, its frame or tab is gone, or the action function
  errors.
- display function, display action function — use **action function**,
  or name the function.
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
- fallback line — say the key for the dispatch prompt default, or name
  the cancel key.
- intended choice — use **dispatch prompt default** for the dispatch
  prompt, **tab prompt default**, or **frame prompt default**.
- window prompt — use **dispatch prompt**.  The current source and
  README still have a separate window prompt; the design uses the
  dispatch prompt.
- dispatch hint — use the **dispatch action list**.  The current source
  and README still show the hint; the design shows the list in the
  dispatch prompt menu.
- transient menu, for the dispatch prompt — use **dispatch prompt
  menu**; the menu is read inside the action function, not a transient
  menu.
- caller action — say the action from the caller's ACTION, or name the
  action function.
- the opt-out, window-settings opt-out — use **window-setting toggle** or
  **window-settings group toggle**, or name the toggle.
- tab reader — for the tab prompt, use **tab prompt**; for the reader,
  use **plain tab reader** or **consult tab reader**.  The current
  source still uses the unqualified term for the reader.
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
