# Changelog

## Unreleased

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
