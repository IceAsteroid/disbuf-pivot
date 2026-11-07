# Git convention

This file is the authority for commits and history in this repository.
Read it before committing.  Commit messages use the terms in
`docs/DOCUMENTATION_CONVENTION.md`; changelog entries follow
`docs/CHANGELOG_CONVENTION.md`.

## Atomic commits

- One atomic commit per logical change: the code and the documentation
  of that change in the same commit, so a checkout of any commit shows
  the code and the documentation that describe it.
- A change that touches only documentation is its own commit;
  unrelated changes are separate commits even when they touch one file.
- Stage explicit paths, never a directory.  The user's uncommitted
  files are not yours; leave a file you were not asked to change alone.

## Subject

- Wrap commit-message lines at about 72 columns.
- A title describes the current behavior; a body paragraph labels the
  change: a fix uses `Symptom:`, `Root cause:`, and `Fix:`; a feature
  uses `Add:`; a documentation-only change is `docs:` and can label
  `Doc:`.
- Subject type prefixes:
  - `feat:` for a new behavior or option.
  - `fix:` for a correction.
  - `refactor:` for a change that keeps behavior.
  - `docs:` for documentation only.
  - `test:` for a change that only adds or changes tests.
  - `build:` for the build system or dependencies.
  - `ci:` for continuous integration.
  - `perf:` for a performance change that keeps behavior.
  - `style:` for formatting or whitespace only.
  - `chore:` for routine maintenance.
  - `revert:` for a revert of an earlier commit.
- Do not rewrite an existing commit.  A message that violates a rule
  written after it keeps its form.
- An assistant-authored commit ends with a `Co-Authored-By:` trailer
  naming the assistant.
