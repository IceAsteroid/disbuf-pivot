# Changelog

## Unreleased

- Add: the four prefix commands identify the package as `disbuf-pivot`
  in the echo area.
- Add: the frame prompt asks for a tab in an existing frame when
  `tab-bar-mode` is active, even when the frame has one tab, so a new tab
  can be made.
- Add: the repeated window prompt says in the echo area that the chosen
  window cannot display the buffer, and shows `? for actions` in the
  mode line when `aw-dispatch-alist` binds `?`.
- Doc: wrap the window prompt docstring at 80 columns.
- Add: `disbuf-pivot-same-window-prefix`; `disbuf-pivot-prefix-mode`
  remaps the four built-in prefix commands to the package commands and
  no longer advises `display-buffer`.  The prefix commands choose the
  last editing window themselves.
- Doc: wrap the frame prompt docstring at 80 columns.
- Doc: the package and repository are `disbuf-pivot`; the source URL
  headers name the new repository, and the local checkout directory
  remains `display-buffer-pivot` until it is renamed.
- Add: `disbuf-pivot-other-frame-prefix`, the frame prefix command; it
  asks for a frame, its tab when it has more than one, and its window.
- Add: a frame name that matches no frame makes a new frame with that
  name; an empty name makes a new frame with the default name.
- Doc: add AGENTS.md and TERM_AND_CONVENTION.md; define the package
  terms there, use Emacs's terms directly in the README, and keep term
  explanations out of the README.
- Doc: state that a new frame uses its selected window and that an
  existing frame asks for its tab first.
- Doc: wrap the option and action docstrings at 80 columns.
- Doc: describe the problem and the explicit choice in the README and
  the main Commentary; leave option defaults to the docstrings and quote
  the quit key in the window prompt docstrings.
- Refactor: disbuf-pivot-window-prefix.el renames to
  disbuf-pivot-prefix.el, and its feature, group, mode and private
  helpers take the prefix name, because the library holds the tab prefix
  as well as the window prefix.
- Refactor: the window prompt moves to disbuf-pivot-window-utility.el
  and tab selection to disbuf-pivot-tab-bar.el, beside the code they
  use.
- Fix: a nil `pop-up-frames` value no longer asks for a frame; the frame
  prompt offers top-level frames with unique names and asks again for an
  unknown name; the tab and frame window prompt honor
  `inhibit-same-window`; the other-window prefix follows
  `reusable-frames` and `inhibit-same-window`; the pivot searches the
  parent frame of a child frame.
- Doc: the optional consult library names `consult` in its Commentary
  and the README; only disbuf-pivot.el carries the package
  `Package-Requires`.
- Add: the display action mode, the window utility, the window prefix
  and the tab bar reader.
- Add: in disbuf-pivot-tab-bar.el, the
  `disbuf-pivot-tab-bar-read-function' option, so a completion
  frontend can replace the plain reader.
- Add: disbuf-pivot-tab-bar-consult.el, the optional consult
  reader and the mode that installs it, with the PGTK child-frame
  cleanup and the minibuffer-height preservation; it needs only consult
  and the display package.
- Fix: in disbuf-pivot.el, a tab name that occurs more than
  once selects its own tab from the tab prompt.
- Doc: the package is `disbuf-pivot`; `disbuf` is the short form of
  `display-buffer`; the source files use `dp-` as a shorthand for
  `disbuf-pivot-`; the repository is `display-buffer-pivot`.
