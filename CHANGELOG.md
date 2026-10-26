# Changelog

## Unreleased

- Add: the display action mode, the window utility, the window prefix
  pivot and the tab bar reader.
- Add: in display-buffer-pivot-tab-bar.el, the
  `display-buffer-pivot-tab-bar-read-function' option, so a completion
  frontend can replace the plain reader.
- Add: display-buffer-pivot-tab-bar-consult.el, the optional consult
  reader and the mode that installs it, with the PGTK child-frame
  cleanup and the minibuffer-height preservation; it needs only consult
  and the display package.
- Fix: in display-buffer-pivot.el, a tab name that occurs more than
  once selects its own tab from the tab prompt.
- Doc: the repository is `display-buffer-pivot`; the package is
  `display-buffer-pivot`.
