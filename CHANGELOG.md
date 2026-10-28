# Changelog

## Unreleased

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
