# Changelog convention

This file is the authority for `CHANGELOG.md`.  Entries use the terms
in `docs/DOCUMENTATION_CONVENTION.md`; commits follow
`docs/GIT_CONVENTION.md`.

## Entries

- Update `CHANGELOG.md` at the top of `## Unreleased` for a
  user-visible or internal change.
- Put user-visible entries first under `### User-visible Changes`,
  internal entries last under `### Internal Changes`, and omit an empty
  section.
- User-visible entries use `Add:`, `Fix:`, or `Doc:` as the label.
- The entry names the change, not a commit hash.
- An internal entry may use the subject type name as its label
  (`Refactor:`, `Build:`, `CI:`, `Test:`, `Docs:`); use `Internal:` when
  one type does not fit.
- A pure refactor with no observable effect may be omitted or
  summarized under `Internal Changes`.
- When a change affects both audiences, state the user-visible effect
  in the user section; do not repeat it in the internal section.
