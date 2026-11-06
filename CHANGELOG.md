# Changelog

## Unreleased

### User-visible Changes

- Doc: describe the consult reader's child-frame cleanup and
  minibuffer-height preservation separately; state the existing-frame
  condition in the frame prefix; qualify the `aw-select` prompt feedback;
  define the window prompt without limiting it to a tab or frame; tighten
  the display action and naming descriptions; correct the 0.1.0 release
  note; and state the pop-up window pairing and enabling order in the
  scope.

### Internal Changes

- Docs: add `docs/DESIGN_RULESET.md` as the design authority, define the
  chosen window, caller intent info, referential, cannot display,
  built-in prefix command, and package prefix command terms in
  `docs/DOCUMENTATION_CONVENTION.md`, and record the settled display
  rules.
- Docs: move the maintainer docs under `docs/` and split the git and
  changelog conventions from the terms file.
- Docs: add `CONTRIBUTING.md` for the developer commands, verification,
  and dependency rules, and reduce `AGENTS.md` to the agent index.

## 0.1.0 - 2026-10-30

### User-visible Changes

- Add: `disbuf-pivot-action-mode`, the display action in
  `display-buffer-alist`.  It reuses a window that displays the buffer,
  uses the selected window, splits, or asks with `ace-window`; a request
  for a tab or frame asks for the target, then for a window when one is
  needed.
- Add: `disbuf-pivot-same-window-prefix`,
  `disbuf-pivot-other-window-prefix`,
  `disbuf-pivot-other-tab-prefix`, and
  `disbuf-pivot-other-frame-prefix`.
  `disbuf-pivot-prefix-mode` remaps the four built-in prefix commands to
  these commands; it does not advise `display-buffer`.
- Add: the prefix commands choose the most recently used editing window
  when the selected window cannot display a buffer.  The window prompt
  says in the echo area when a chosen window cannot display the buffer,
  and shows `? for actions` when `aw-dispatch-alist` binds `?`.
- Add: the frame prompt offers top-level frames, disambiguates repeated
  names, makes a new frame for a new name, and asks for a tab when
  `tab-bar-mode` is active or the frame has more than one tab.
- Add: `disbuf-pivot-tab-bar-read-tab-name` reads tab names from the
  tab bar, the closed-tab history, the configured sort, and the
  annotations.  In `disbuf-pivot-tab-bar.el`,
  `disbuf-pivot-tab-bar-read-function` can replace the plain reader.
- Add: `disbuf-pivot-tab-bar-consult.el`, the optional consult reader
  and the mode that installs it, with the PGTK child-frame cleanup and
  the minibuffer-height preservation.  It needs only `consult` and the
  display package.
- Fix: a nil `pop-up-frames` value no longer asks for a frame; child
  frames are not offered; repeated frame names are disambiguated; the
  tab and frame window prompts honor `inhibit-same-window`; the
  other-window prefix follows `reusable-frames` and
  `inhibit-same-window`; a tab name that occurs more than once selects
  its own tab; the pivot searches the parent frame of a child frame.
- Doc: the package and repository are `disbuf-pivot`; the source URL
  headers name the repository, and the README and codification describe
  the behavior and terms.
