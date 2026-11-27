# disbuf-pivot — Terms and documentation convention

This file is the authority for terms, prose, and documentation
conventions.  It applies to code, Commentary, docstrings, `README.md`,
`CHANGELOG.md`, `CONTRIBUTING.md`, `docs/`, and commit messages.
`CONTRIBUTING.md` is the authority for commands, verification, commits,
and changelog structure; `docs/DESIGN_RULESET.md` is the authority for
intended behavior.  Define what a term means here; specify behavioral
rules and key assignments in `docs/DESIGN_RULESET.md`.  The
`emacs-utils` and `column-popup` files are models; they do not govern
this repository.

## Core terms

Emacs's terms and common technical terms are used as they are.  The
entries below are this package's terms, grouped by concept.

### Pivot, targets, and prefixes

- **pivot**, **outside the pivot** — the pivot is the point at which
  the package either respects the effective intent or replaces that
  intent with the user's explicit choice.  A tab prompt is outside the
  pivot when neither the package's `display-buffer-alist` entry nor a
  package prefix command shows it.  The package name uses the word.
- **target**, **placement path** — a target is a frame, tab, or window
  that the effective intent names or the user chooses through a prompt.
  A frame or tab target is a container; a window target is the window
  that displays the buffer.  The placement path is the sequence frame,
  then tab, then window; tab, then window; or window, ending at the
  window that displays the buffer.
- **built-in prefix command**, **package prefix command** — a built-in
  prefix command is one of Emacs's `same-window-prefix`,
  `other-window-prefix`, `other-tab-prefix`, and `other-frame-prefix`;
  it sets `display-buffer-overriding-action` for the next command.  A
  package prefix command is one of `disbuf-pivot-same-window-prefix`,
  `disbuf-pivot-other-window-prefix`,
  `disbuf-pivot-other-tab-prefix`, and
  `disbuf-pivot-other-frame-prefix`; `disbuf-pivot-prefix-mode` remaps
  the built-in prefix commands to these commands.
- **excluded buffer** — a buffer that matches
  `disbuf-pivot-exclude-conditions`; the package does not regulate it.

### Window predicates

- **displayable window**, **undisplayable window** — a displayable
  window can directly display a given buffer: it is live, is not a
  minibuffer window, is not a side window, and is not dedicated to
  *another* buffer (a non-side window dedicated to the buffer being
  displayed is displayable).  An undisplayable window is dead, a
  minibuffer window, a side window, or dedicated to another buffer.
- **eligible window**, **ineligible window** — an eligible window is a
  displayable window that the current dispatch prompt offers for direct
  display.  Effective intent never makes a displayable window
  ineligible; only an undisplayable window, or the selected window under
  explicit user intent (`disbuf-pivot-other-window-prefix`), is
  ineligible.
- **splittable window**, **unsplittable window** — a splittable window
  is a window that a split action can split to make a new displayable
  window: it is live, is not a minibuffer window, is not a side window,
  and its frame is not `unsplittable`.  A dedicated normal window is
  undisplayable yet splittable, because splitting it makes a fresh
  non-dedicated window while leaving the original window dedicated.  An
  unsplittable window is dead, a minibuffer window, a side window, or
  on an `unsplittable` frame.

### Caller intent, effective intent, and action alist roles

- **caller**, **caller's ACTION**, **caller's function list**,
  **caller's action function**, **caller's fallback chain** — the
  caller is the code that calls `display-buffer` (do not use the word
  for code that shows the tab prompt).  The caller's ACTION is the
  `ACTION` argument of the `display-buffer` call: a `(FUNCTIONS . ALIST)`
  pair, `nil`, or a non-list value such as `t`.  Its `FUNCTIONS` are the
  caller's function list (one function or a list); each function in it
  is a caller's action function; the functions after the primary one
  form the caller's fallback chain.
- **caller intent**, **effective intent**, **intent class**,
  **effect**, **caller intent info** — the caller intent is what the
  caller's ACTION alone asks for.  The effective intent is the intent
  that the pivot classifies for a `display-buffer` call—derived from the
  caller intent together with the relevant combined action alist entries
  and Emacs display variables (see `docs/DESIGN_RULESET.md` section 3).
  The intent class classifies the effective intent into fixed place, tab
  or frame, relative placement, strategy, no display, or no preference.
  An effect is a user-facing phrase for a consequence other than the
  primary placement (a window setting, constraint, display outcome, or
  fallback placement), not a raw Lisp symbol or alist cell.  The caller
  intent info is the part of header info that summarizes the caller's
  ACTION alone: its primary intent, the effects of its primary intent
  and the caller's action alist entries, and the caller's fallback chain
  (for a package prefix command, the user's prefix request).
- **source label**, **source-labeled entries**, **window fact** — a
  source label is the short label used in the dispatch prompt menu when
  an action alist entry comes from an action other than the caller's
  ACTION: `display-buffer-base-action` as `"base action"`,
  `display-buffer-overriding-action` as `"overriding action"`,
  `display-buffer-fallback-action` as `"fallback action"`, and the
  extra action as `"extra action"` (use the full variable names outside
  the dispatch prompt menu).  Source-labeled entries are those
  non-caller entries shown in header info.  A window fact is a relevant
  fact about the current layout or buffer display shown in header info
  (such as whether the selected window can display, or which windows
  already display the buffer).
- **caller constraint**, **selection entry**, **window-setting entry**
  — an entry in these terms is an action alist entry, never a dispatch
  prompt key.  A caller constraint is an action alist entry from the
  caller's ACTION that limits or orders candidate windows (such as
  `reusable-frames`, `previous-window`, `frame-predicate`,
  `window-min-width`, `window-min-height`).  A selection entry limits,
  orders, or chooses the candidate target or display outcome during the
  prompt and is not applied to the chosen window afterward.  A
  window-setting entry changes the chosen window itself (`dedicated`,
  `window-parameters`, `preserve-size`, `window-height`,
  `window-width`, `window-size`); `body-function` is not a
  window-setting entry.
- **tab or frame action**, **child-frame action** — a tab or frame
  action is `display-buffer-in-tab`, `display-buffer-in-new-tab`,
  `display-buffer-pop-up-frame`, or `display-buffer-use-some-frame`.  A
  child-frame action is `display-buffer-in-child-frame`.

### Dispatch prompt and menu

- **dispatch prompt**, **dispatch prompt default**, **chosen window** —
  the dispatch prompt is the package's synchronous interaction at the
  pivot; it does not return to `display-buffer` until the user chooses.
  It has two parts: window labels drawn on the windows in the window
  label scope, and the dispatch prompt menu.  The dispatch prompt
  default is the window or dispatch action offered as the default
  choice with its key (or none when no default applies); accepting it
  means pressing that key.  The chosen window is the window the user
  chooses through a prompt or split action (a silent default is not a
  chosen window).
- **window label**, **window label scope** — a window label is a key
  drawn on a window by the dispatch prompt and repeated in the Windows
  group with the same face (`disbuf-pivot-eligible-label` or
  `disbuf-pivot-ineligible-label`).  The window label scope is the set
  of windows labeled: the selected tab's windows when `tab-bar-mode` is
  active, otherwise the selected frame's windows.  The dispatch prompt
  menu window is outside the scope.
- **dispatch prompt key**, **dispatch action**, **split action**,
  **dispatch action list** — a dispatch prompt key is any key the
  dispatch prompt reads: a window label, dispatch action,
  window-setting toggle, window-settings group toggle, or the bypass
  key.  A dispatch action is a command key in the dispatch prompt menu
  run instead of a window label; a split action splits a splittable
  window and displays the buffer in the new window.  The dispatch
  action list is the grouped set of actions (Split, Caller intent,
  Other) shown in the dispatch action group.
- **dispatch prompt menu**, **dispatch prompt menu window**,
  **dispatch prompt menu header**, **header info**,
  **dispatch prompt menu group** — the dispatch prompt menu is the
  synchronous side-window menu (not a transient menu) shown in the
  dispatch prompt menu window.  The dispatch prompt menu header sits
  above the groups and holds header info and the dispatch prompt
  default.  Header info is the optional informational part of the
  dispatch prompt menu header (controlled by `disbuf-pivot-header-info`),
  composed of caller intent info, source-labeled entries, and window
  facts.  The three horizontal
  dispatch prompt menu groups are the **Windows group**, the **dispatch
  action group** ("Dispatch actions"), and the **window-settings group**
  ("Window settings").
- **window-setting toggle**, **window-settings group toggle** — a
  window-setting toggle is a stay-open key in the window-settings group
  for a present window-setting entry; toggling it off locally shadows
  that entry's key with `nil` for the package's display call or caller
  run without altering the caller's ACTION or later calls.  The
  window-settings group toggle toggles all present window-setting
  entries at once and shows `on`, `off`, or `mixed`.

### Tab prompt and frame prompt

- **tab prompt**, **tab prompt default**, **frame prompt**,
  **frame prompt default** — the tab prompt reads a tab name
  (`disbuf-pivot-tab-bar-read-tab-name`); choosing an existing name
  selects that tab and a new name makes a new tab.  The tab prompt
  default is the preselected tab, if any.  The frame prompt reads a
  frame name from live visible top-level frames filtered by
  `frame-predicate`; an existing name selects the frame, a new name
  makes a named frame, and an empty name makes a new frame with the
  default name.  The frame prompt default is the preselected existing
  frame or a new frame with the default name.
- **plain tab reader**, **consult tab reader** — the plain tab reader
  is the built-in `completing-read` implementation used when
  `disbuf-pivot-tab-bar-read-function` is nil.  The consult tab reader
  is the optional reader in `disbuf-pivot-tab-bar-consult.el`,
  installed by `disbuf-pivot-tab-bar-consult-mode`, which uses
  `consult` and supplies previews.
- **tab prompt scope** — the frames whose tabs the tab prompt offers:
  nil (selected frame), `t` (all existing frames), `visible` (visible
  frames), `0` (all frames on the current terminal), or a specific
  frame.  (Differs from `display-buffer-in-tab`'s `reusable-frames`,
  where nil means no reusable search.)
- **tab candidate annotation**, **tab annotation column**,
  **tab history candidate** — the tab candidate annotation is the text
  the package (not Marginalia) appends to a tab candidate; a tab
  annotation column is one field in it (state, frame, window count,
  group, or buffer).  A tab history candidate is a name from tab
  history matching no offered existing tab in the current prompt,
  marked `(closed)` relative to that prompt's scope.

### Outcomes and contexts

- **cannot prompt**, **no prompt** — the package cannot prompt in
  contexts where interactive input is impossible (batch, active
  minibuffer, timer, process filter, keyboard macro, or recursive
  display); in those contexts the action returns nil.  No prompt means
  the rule displays without asking (or returns nil in a cannot-prompt
  context).  Use "no prompt" in tables and "do not prompt" in prose.
- **abort**, **nil choice**, **failure after the choice** — an abort
  (`C-g`, via `quit`) ends the display without running later functions
  in the combined function list; the leave-undisplayed outcome (`fail`)
  is not an abort.  A nil choice is the prompt returning nil without
  `C-g` (such as the bypass key, `"Bypass pivot"`), causing the action
  to return nil so later functions in Emacs's combined function list
  run.  A failure
  after the choice is a failure once the user has chosen a target or
  dispatch action (dead window, vanished tab or frame, split failure,
  or an action function returning nil or signaling an error).

## Emacs terms used by the design

- **action alist entry** — an association in an action alist.  A
  `display-buffer-alist` element is not an action alist entry.
- **action function** — a function accepting `(BUFFER ALIST)` that
  tries to display the buffer and returns a window, `fail`, or nil;
  `display-buffer` calls it.  A tab or frame action is an action
  function; a dispatch action is not.
- **`display-buffer-alist` entry**, **display action**, **action alist**
  — a `display-buffer-alist` entry has the form `(CONDITION . ACTION)`,
  where `CONDITION` is a `buffer-match-p` condition and `ACTION` is a
  display action `(FUNCTIONS . ALIST)`.  `FUNCTIONS` is one action
  function, a list of action functions, or nil; `ALIST` is an
  association list of action alist entries.
- **combined action alist**, **combined function list** — the two lists
  `display-buffer` builds by combining, in order,
  `display-buffer-overriding-action`, the matching
  `display-buffer-alist` entry, the special action, the caller's ACTION,
  the extra action (non-list `ACTION` and the `FRAME` argument),
  `display-buffer-base-action`, and `display-buffer-fallback-action`.
  In the combined action alist, the first association of a key wins.
  `display-buffer` calls the combined function list in order without
  deduplicating, passing the combined action alist to each, until one
  returns non-nil.
- **top-level frame**, **child frame** — a top-level frame has a nil
  `parent-frame` parameter; a child frame has a non-nil `parent-frame`
  parameter and is displayed within its parent frame.
- **reusable tab** — a tab in one of the frames named by a non-nil
  `reusable-frames` entry that already displays the buffer (found with
  `tab-bar-get-buffer-tab`).
- **transient menu**, **transient prefix command**,
  **transient suffix command**, **transient stay suffix**,
  **transient exit suffix** — Emacs `transient.el` terms.  Always use
  the qualified form; a bare "prefix command" means a built-in prefix
  command or package prefix command.

## Terms not used

Avoid these forms in Commentary, docstrings, `README.md`,
`CHANGELOG.md`, `CONTRIBUTING.md`, `docs/`, and commit messages.  Shell
commands, identifiers, and code fragments are not prose.

- dispatch prompt's menu — use **dispatch prompt menu**.
- menu item, menu entry, or bare "entry" for a key in the menu — use
  **window label**, **dispatch action**, or **window-setting toggle**;
  bare "entry" means an action alist entry.
- menu group — use **dispatch prompt menu group**.
- namespace (for a key class) — name the specific dispatch prompt key:
  window labels, dispatch actions, or window-setting toggles.
- utility popup — use **dedicated window**, **side window**,
  **child frame**, or **undisplayable window**.
- physical / physically (for an undisplayable window) — say
  **undisplayable window** or cannot display, and name the condition.
- failed interactive display — name the failure (dead window, gone
  frame or tab, split failure, nil return, or error).
- display function, display action function — use **action function**,
  or name the function.
- display action (for the package's entry) — say **the package's
  `display-buffer-alist` entry**, or name the condition and function.
- merged alist — use **combined action alist**.
- flow (for the frame/tab/window sequence) — use **placement path**.
- driver — say that the package reads the keys, or name the function.
- placement entry — say **entry that names a place**, or name the entry.
- fallback line — say the key for the dispatch prompt default, or name
  the bypass key.
- cancel key — use **bypass key** (`"Bypass pivot"`, nil choice); `C-g`
  is **abort**.
- intended choice — use **dispatch prompt default**,
  **tab prompt default**, or **frame prompt default**.
- window prompt — use **dispatch prompt** in design docs (current
  v0.1.0 source and `README.md` still have a separate window prompt).
- dispatch hint — use **dispatch action list** in design docs (current
  v0.1.0 source and `README.md` still show a hint).
- transient menu (for the dispatch prompt) — use **dispatch prompt
  menu**; the package reads keys synchronously inside the action
  function and does not call a transient prefix command.
- caller action — say the action from the caller's ACTION, or name the
  action function.
- the opt-out, window-settings opt-out — use **window-setting toggle**
  or **window-settings group toggle**.
- bare "tab reader" or "frame reader" — use **tab prompt**,
  **plain tab reader**, **consult tab reader**, or **frame prompt**.
- split rule — name `disbuf-pivot-window-utility-split-p` and its
  options (not consulted by the redesigned core).
- no-prompt — use **no prompt**.
- workspace — use **window**, or name the function that returns it.
- editing window — say **displayable window**, or "the most recently
  used displayable window."
- frame title (for the `name` parameter) — use **frame name**.
- popup as a noun — use **pop-up window**, or name the condition.
- adopt / adopted — say use, select, or apply.
- session — say the call, the command, or "while the minibuffer is
  active."
- the echo — use **echo area** (identifiers keep the `echo` prefix).
- task context — delete, or say "the minibuffer."
- claim / claimed — state what the window, function, or mode does.
- stays / stayed — use "remains / remained."
- summon / summoned, spawn / spawned / spawning — say "display /
  displayed" for a buffer, "make / made" for a window, frame, or tab.
- open a buffer / create a buffer — say "display a buffer in a window"
  (or name `get-buffer-create` when a buffer is actually created).
- question (for `completing-read`) — say "prompt," or name the function.

## Conventions

- Prefer Emacs's term before a package term; use a package term when
  Emacs has no concise word and the term is defined above.
- Do not introduce a new controlled term without the maintainer's
  agreement.  Add agreed terms to Core terms; move dropped terms to
  Terms not used with their replacement.
- Keep term definitions in this file.  `README.md` uses the terms and
  adds inline explanations only when needed to use the package; do not
  redefine Emacs or common technical terms in parentheses, and do not
  use footnotes for definitions.
- Use present tense for verbs.
- Commit messages and changelog entries follow `CONTRIBUTING.md` and
  use the terms in this file.
- Wrap Elisp docstrings at 80 columns (`defvar`/`defcustom` lines over
  80 columns trigger byte-compiler warnings; `checkdoc` flags the rest).
- Only the package main file (`disbuf-pivot.el`) carries
  `Package-Requires`.  Other libraries name optional dependencies in
  their Commentary and `README.md`.
- Quote symbols and code fragments with `` `...` `` in Markdown and
  commit messages, and with `` `...' `` in Emacs Lisp source.
- Verification and dependency rules are in `CONTRIBUTING.md`.
